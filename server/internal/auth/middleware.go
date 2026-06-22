package auth

import (
	"context"
	"errors"
	"net/http"
	"strings"

	"github.com/jackc/pgx/v5"
	"raai/internal/db/sqlc"
	"raai/internal/httpx"
)

// Middleware validates bearer tokens and loads the authoritative user so role and
// admin status reflect the database, not stale token claims.
type Middleware struct {
	tokens *TokenManager
	q      *sqlc.Queries
}

func NewMiddleware(tokens *TokenManager, q *sqlc.Queries) *Middleware {
	return &Middleware{tokens: tokens, q: q}
}

// Authenticator rejects requests without a valid bearer token (401) and otherwise
// injects the caller's Identity into the context.
func (m *Middleware) Authenticator(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		raw := bearerToken(r)
		if raw == "" {
			httpx.WriteError(w, r, httpx.ErrUnauthorized("missing bearer token"))
			return
		}
		uid, phone, err := m.tokens.Parse(raw)
		if err != nil {
			httpx.WriteError(w, r, httpx.ErrUnauthorized("invalid or expired token"))
			return
		}
		user, err := m.q.GetUserByID(r.Context(), uid)
		if err != nil {
			if errors.Is(err, pgx.ErrNoRows) {
				httpx.WriteError(w, r, httpx.ErrUnauthorized("account no longer exists"))
				return
			}
			httpx.WriteError(w, r, err)
			return
		}
		id := Identity{UserID: user.ID, Phone: phone, Role: user.Role, IsAdmin: user.IsAdmin}
		next.ServeHTTP(w, r.WithContext(withIdentity(r.Context(), id)))
	})
}

// RequireAdmin gates JSON admin endpoints; non-admins get 403 (§7.3).
func (m *Middleware) RequireAdmin(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		id, ok := FromContext(r.Context())
		if !ok || !id.IsAdmin {
			httpx.WriteError(w, r, httpx.ErrForbidden("admin access required"))
			return
		}
		next.ServeHTTP(w, r)
	})
}

func bearerToken(r *http.Request) string {
	h := r.Header.Get("Authorization")
	const prefix = "Bearer "
	if len(h) > len(prefix) && strings.EqualFold(h[:len(prefix)], prefix) {
		return strings.TrimSpace(h[len(prefix):])
	}
	return ""
}

// ContextWithIdentity is exported for the dashboard's cookie-session transport,
// which authenticates differently but reuses the same Identity contract.
func ContextWithIdentity(ctx context.Context, id Identity) context.Context {
	return withIdentity(ctx, id)
}
