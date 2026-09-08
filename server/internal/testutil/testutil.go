// Package testutil spins up the real HTTP app against a real Postgres so the
// integration tests exercise handlers, middleware, SQL and transactions together
// rather than mocks.
//
// Tests are skipped unless TEST_DATABASE_URL points at a database the suite may
// wipe, e.g.
//
//	docker compose up -d db
//	TEST_DATABASE_URL='postgres://raai:raai@localhost:5432/raai_test?sslmode=disable' go test ./...
package testutil

import (
	"bytes"
	"context"
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"os"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"

	"raai/internal/config"
	"raai/internal/db"
	"raai/internal/server"
)

// DSNEnv names the environment variable holding the test database DSN.
const DSNEnv = "TEST_DATABASE_URL"

// migrateOnce runs the embedded migrations a single time per test binary; each
// test then starts from truncated tables rather than a rebuilt schema.
var migrateOnce sync.Once

// Env is one test's isolated view of the app: an empty database, a fresh handler
// (so per-App rate limiters never bleed across tests), and a live HTTP server.
type Env struct {
	T      *testing.T
	Pool   *pgxpool.Pool
	Server *httptest.Server
	Client *http.Client
}

// New returns a ready Env with empty tables, or skips the test when no test
// database is configured.
func New(t *testing.T) *Env {
	t.Helper()

	dsn := os.Getenv(DSNEnv)
	if dsn == "" {
		t.Skipf("set %s to run integration tests", DSNEnv)
	}

	ctx := context.Background()
	pool, err := db.NewPool(ctx, dsn)
	if err != nil {
		t.Fatalf("connect test db: %v", err)
	}
	t.Cleanup(pool.Close)

	var migErr error
	migrateOnce.Do(func() { _, migErr = db.MigrateUp(ctx, pool) })
	if migErr != nil {
		t.Fatalf("migrate test db: %v", migErr)
	}
	truncateAll(t, pool)

	cfg := &config.Config{
		Addr:                ":0",
		DatabaseURL:         dsn,
		JWTKey:              "test-signing-key",
		JWTIssuer:           "raai",
		JWTAudience:         "raai-app",
		AccessTokenTTL:      time.Hour,
		RefreshTokenTTL:     7 * 24 * time.Hour,
		InstapayIPA:         "raai@instapay",
		InstapayDisplayName: "Raai Test",
		PriceMonthlyEGP:     150,
		PriceYearlyEGP:      1500,
		SecureCookies:       false,
	}

	app, err := server.New(cfg, pool)
	if err != nil {
		t.Fatalf("build app: %v", err)
	}
	srv := httptest.NewServer(app.Handler)
	t.Cleanup(srv.Close)

	return &Env{
		T:      t,
		Pool:   pool,
		Server: srv,
		// Redirects would hide the dashboard's 303s, which some tests assert on.
		Client: &http.Client{
			Timeout:       10 * time.Second,
			CheckRedirect: func(*http.Request, []*http.Request) error { return http.ErrUseLastResponse },
		},
	}
}

// truncateAll empties every application table, leaving schema_migrations intact so
// the schema is migrated once per binary.
func truncateAll(t *testing.T, pool *pgxpool.Pool) {
	t.Helper()
	ctx := context.Background()

	rows, err := pool.Query(ctx, `
		SELECT tablename FROM pg_tables
		WHERE schemaname = 'public' AND tablename <> 'schema_migrations'`)
	if err != nil {
		t.Fatalf("list tables: %v", err)
	}
	var tables []string
	for rows.Next() {
		var name string
		if err := rows.Scan(&name); err != nil {
			rows.Close()
			t.Fatalf("scan table name: %v", err)
		}
		tables = append(tables, `"`+name+`"`)
	}
	rows.Close()
	if err := rows.Err(); err != nil {
		t.Fatalf("list tables: %v", err)
	}
	if len(tables) == 0 {
		return
	}
	if _, err := pool.Exec(ctx, "TRUNCATE "+strings.Join(tables, ", ")+" RESTART IDENTITY CASCADE"); err != nil {
		t.Fatalf("truncate: %v", err)
	}
}

// --- HTTP helpers ---

// Resp is a captured response: status plus the raw body, so a test can assert on
// the error envelope as easily as on the success payload.
type Resp struct {
	T      *testing.T
	Status int
	Body   []byte
}

// Do sends a JSON request to the API. An empty token sends no Authorization
// header; a nil body sends no body.
func (e *Env) Do(method, path, token string, body any) *Resp {
	e.T.Helper()

	var reader io.Reader
	if body != nil {
		raw, err := json.Marshal(body)
		if err != nil {
			e.T.Fatalf("marshal request: %v", err)
		}
		reader = bytes.NewReader(raw)
	}
	req, err := http.NewRequest(method, e.Server.URL+path, reader)
	if err != nil {
		e.T.Fatalf("build request: %v", err)
	}
	if body != nil {
		req.Header.Set("Content-Type", "application/json")
	}
	if token != "" {
		req.Header.Set("Authorization", "Bearer "+token)
	}
	resp, err := e.Client.Do(req)
	if err != nil {
		e.T.Fatalf("%s %s: %v", method, path, err)
	}
	defer resp.Body.Close()
	raw, err := io.ReadAll(resp.Body)
	if err != nil {
		e.T.Fatalf("read body: %v", err)
	}
	return &Resp{T: e.T, Status: resp.StatusCode, Body: raw}
}

// ExpectStatus fails the test unless the response carries the wanted status.
func (r *Resp) ExpectStatus(want int) *Resp {
	r.T.Helper()
	if r.Status != want {
		r.T.Fatalf("status = %d, want %d (body: %s)", r.Status, want, r.Body)
	}
	return r
}

// JSON decodes the body into dst.
func (r *Resp) JSON(dst any) *Resp {
	r.T.Helper()
	if err := json.Unmarshal(r.Body, dst); err != nil {
		r.T.Fatalf("decode body %q: %v", r.Body, err)
	}
	return r
}

// ErrorCode returns the snake_case code from the {error:{code,message}} envelope.
func (r *Resp) ErrorCode() string {
	r.T.Helper()
	var env struct {
		Error struct {
			Code   string            `json:"code"`
			Fields map[string]string `json:"fields"`
		} `json:"error"`
	}
	if err := json.Unmarshal(r.Body, &env); err != nil {
		r.T.Fatalf("decode error envelope %q: %v", r.Body, err)
	}
	return env.Error.Code
}

// --- domain fixtures ---

// Account is a registered user with their tokens and farm.
type Account struct {
	Phone   string
	UserID  int32
	FarmID  int32
	Access  string
	Refresh string
}

// Register creates a farm admin (registration always creates a farm) and returns
// the account with a usable access token.
func (e *Env) Register(phone, password, farmName string) *Account {
	e.T.Helper()

	var tokens struct {
		AccessToken  string `json:"accessToken"`
		RefreshToken string `json:"refreshToken"`
	}
	e.Do(http.MethodPost, "/api/v1/auth/register", "", map[string]string{
		"phoneNumber": phone,
		"password":    password,
		"farmName":    farmName,
	}).ExpectStatus(http.StatusCreated).JSON(&tokens)

	acct := &Account{Phone: phone, Access: tokens.AccessToken, Refresh: tokens.RefreshToken}

	var me struct {
		ID   int32 `json:"id"`
		Farm struct {
			ID int32 `json:"id"`
		} `json:"farm"`
	}
	e.Do(http.MethodGet, "/api/v1/me", acct.Access, nil).
		ExpectStatus(http.StatusOK).JSON(&me)
	acct.UserID, acct.FarmID = me.ID, me.Farm.ID
	return acct
}

// Activate gives a farm a live subscription so the paywall gate lets it through.
func (e *Env) Activate(farmID int32) {
	e.T.Helper()
	_, err := e.Pool.Exec(context.Background(), `
		INSERT INTO subscriptions (farm_id, plan, status, current_period_end, updated_at)
		VALUES ($1, 'monthly', 'active', now() + interval '30 days', now())
		ON CONFLICT (farm_id) DO UPDATE
		SET status = 'active', current_period_end = now() + interval '30 days'`, farmID)
	if err != nil {
		e.T.Fatalf("activate farm %d: %v", farmID, err)
	}
}

// MakeSuperAdmin flips users.is_admin so the account can reach /api/v1/admin.
func (e *Env) MakeSuperAdmin(userID int32) {
	e.T.Helper()
	if _, err := e.Pool.Exec(context.Background(),
		`UPDATE users SET is_admin = true WHERE id = $1`, userID); err != nil {
		e.T.Fatalf("grant super admin: %v", err)
	}
}

// CreateAnimal registers an ear tag in the caller's farm and returns its id.
func (e *Env) CreateAnimal(token, barcode string) int32 {
	e.T.Helper()
	var animal struct {
		ID int32 `json:"id"`
	}
	e.Do(http.MethodPost, "/api/v1/animals", token, map[string]string{"barcode": barcode}).
		ExpectStatus(http.StatusCreated).JSON(&animal)
	return animal.ID
}
