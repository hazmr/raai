// Package idempotency makes retried creates safe (§6.1).
//
// The app queues ear tags and notes in a local outbox while a farmer is out of
// signal and replays them when the connection returns, so the same POST can
// legitimately arrive twice. The first request claims the key and stores its
// response; a replay carrying the same key gets that stored response back rather
// than creating a second row.
//
// Only successful (2xx) responses are stored. A failure releases the key so the
// client's next attempt runs for real — a note POSTed before its animal finished
// syncing must be able to succeed on retry.
package idempotency

import (
	"bytes"
	"context"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"io"
	"log/slog"
	"net/http"

	"github.com/jackc/pgx/v5"

	"raai/internal/auth"
	"raai/internal/db/sqlc"
	"raai/internal/httpx"
)

const (
	// HeaderKey is the request header carrying the client's key.
	HeaderKey = "Idempotency-Key"

	maxKeyLen = 200
	// Bodies are already capped at 1 MiB by httpx.DecodeJSON; mirror that here.
	maxBodyBytes = 1 << 20
	// ReplayWindowHours is how long a stored response stays replayable.
	ReplayWindowHours = 24
)

// Middleware replays stored responses for repeated Idempotency-Key requests.
type Middleware struct {
	q *sqlc.Queries
}

func New(q *sqlc.Queries) *Middleware { return &Middleware{q: q} }

// Handler wraps authenticated routes. Requests without the header, and anything
// that is not a POST, pass straight through.
func (m *Middleware) Handler(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		key := r.Header.Get(HeaderKey)
		if key == "" || r.Method != http.MethodPost {
			next.ServeHTTP(w, r)
			return
		}
		if len(key) > maxKeyLen {
			httpx.WriteError(w, r, httpx.ErrBadRequest("Idempotency-Key is too long"))
			return
		}
		caller, ok := auth.FromContext(r.Context())
		if !ok {
			// Unauthenticated routes have no farm to scope the key to.
			next.ServeHTTP(w, r)
			return
		}

		body, err := io.ReadAll(io.LimitReader(r.Body, maxBodyBytes))
		if err != nil {
			httpx.WriteError(w, r, httpx.ErrBadRequest("could not read request body"))
			return
		}
		_ = r.Body.Close()
		r.Body = io.NopCloser(bytes.NewReader(body))

		hash := fingerprint(r.Method, r.URL.Path, body)
		ctx := r.Context()

		_, err = m.q.ClaimIdempotencyKey(ctx, sqlc.ClaimIdempotencyKeyParams{
			FarmID:      caller.FarmID,
			Key:         key,
			RequestHash: hash,
		})
		switch {
		case err == nil:
			// We own the key: run the handler and record what it returned.
			m.runAndRecord(next, w, r, caller.FarmID, key)
			return
		case errors.Is(err, pgx.ErrNoRows):
			m.replay(next, w, r, caller.FarmID, key, hash)
			return
		default:
			httpx.WriteError(w, r, err)
			return
		}
	})
}

// runAndRecord executes the handler, buffering the response so a success can be
// stored for replay and a failure can release the claim.
func (m *Middleware) runAndRecord(next http.Handler, w http.ResponseWriter, r *http.Request, farmID int32, key string) {
	rec := &recorder{header: http.Header{}, status: http.StatusOK}

	// A panic must not leave the key claimed forever; release, then let the
	// router's recoverer turn it into a 500.
	completed := false
	defer func() {
		if !completed {
			m.release(r.Context(), farmID, key)
		}
	}()

	next.ServeHTTP(rec, r)
	completed = true

	if rec.status >= 200 && rec.status < 300 {
		if err := m.q.CompleteIdempotencyKey(r.Context(), sqlc.CompleteIdempotencyKeyParams{
			FarmID:       farmID,
			Key:          key,
			StatusCode:   &rec.status,
			ResponseBody: rec.body.Bytes(),
		}); err != nil {
			// The response is still valid; only the replay guarantee is lost.
			slog.ErrorContext(r.Context(), "store idempotent response", "err", err, "path", r.URL.Path)
		}
	} else {
		m.release(r.Context(), farmID, key)
	}
	rec.flushTo(w)
}

// replay returns the stored response for a key that has already been used.
func (m *Middleware) replay(next http.Handler, w http.ResponseWriter, r *http.Request, farmID int32, key, hash string) {
	existing, err := m.q.GetIdempotencyKey(r.Context(), sqlc.GetIdempotencyKeyParams{FarmID: farmID, Key: key})
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			// Purged between the claim attempt and this read — treat as a fresh request.
			m.runAndRecord(next, w, r, farmID, key)
			return
		}
		httpx.WriteError(w, r, err)
		return
	}
	if existing.RequestHash != hash {
		httpx.WriteError(w, r, httpx.ErrConflict("this Idempotency-Key was used for a different request"))
		return
	}
	if existing.StatusCode == nil {
		httpx.WriteError(w, r, httpx.ErrConflict("a request with this Idempotency-Key is still in progress"))
		return
	}
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.Header().Set("Idempotent-Replay", "true")
	w.WriteHeader(int(*existing.StatusCode))
	_, _ = w.Write(existing.ResponseBody)
}

func (m *Middleware) release(ctx context.Context, farmID int32, key string) {
	if err := m.q.ReleaseIdempotencyKey(ctx, sqlc.ReleaseIdempotencyKeyParams{FarmID: farmID, Key: key}); err != nil {
		slog.ErrorContext(ctx, "release idempotency key", "err", err)
	}
}

// fingerprint identifies the request a key was first used for, so reusing one key
// for a different payload is caught instead of silently replaying the wrong body.
func fingerprint(method, path string, body []byte) string {
	sum := sha256.New()
	sum.Write([]byte(method))
	sum.Write([]byte("\n"))
	sum.Write([]byte(path))
	sum.Write([]byte("\n"))
	sum.Write(body)
	return hex.EncodeToString(sum.Sum(nil))
}

// recorder buffers a handler's response so it can be stored before being sent.
type recorder struct {
	header http.Header
	body   bytes.Buffer
	status int32
	wrote  bool
}

func (rec *recorder) Header() http.Header { return rec.header }

func (rec *recorder) WriteHeader(status int) {
	if rec.wrote {
		return
	}
	rec.status = int32(status)
	rec.wrote = true
}

func (rec *recorder) Write(p []byte) (int, error) {
	if !rec.wrote {
		rec.WriteHeader(http.StatusOK)
	}
	return rec.body.Write(p)
}

func (rec *recorder) flushTo(w http.ResponseWriter) {
	for k, values := range rec.header {
		for _, v := range values {
			w.Header().Add(k, v)
		}
	}
	w.WriteHeader(int(rec.status))
	_, _ = w.Write(rec.body.Bytes())
}
