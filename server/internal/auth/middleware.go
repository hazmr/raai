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

// Middleware validates bearer tokens and loads the authoritative principal so role,
// farm, admin status, and (for doctors) invite validity reflect the database, not
// stale token claims.
type Middleware struct {
	tokens *TokenManager
	q      *sqlc.Queries
}

func NewMiddleware(tokens *TokenManager, q *sqlc.Queries) *Middleware {
	return &Middleware{tokens: tokens, q: q}
}

// Authenticator rejects requests without a valid bearer token (401) and otherwise
// injects the caller's Identity. Doctor sessions are re-validated against the
// invite on every request, so ending an invite revokes access immediately.
func (m *Middleware) Authenticator(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		raw := bearerToken(r)
		if raw == "" {
			httpx.WriteError(w, r, httpx.ErrUnauthorized("missing bearer token"))
			return
		}
		claims, err := m.tokens.Parse(raw)
		if err != nil {
			httpx.WriteError(w, r, httpx.ErrUnauthorized("invalid or expired token"))
			return
		}

		var id Identity
		if claims.Kind == KindDoctor {
			id, err = m.doctorIdentity(r.Context(), claims)
		} else {
			id, err = m.userIdentity(r.Context(), claims)
		}
		if err != nil {
			httpx.WriteError(w, r, err)
			return
		}
		next.ServeHTTP(w, r.WithContext(withIdentity(r.Context(), id)))
	})
}

func (m *Middleware) userIdentity(ctx context.Context, claims *Claims) (Identity, error) {
	uid, err := claims.SubjectID()
	if err != nil {
		return Identity{}, httpx.ErrUnauthorized("invalid token subject")
	}
	user, err := m.q.GetUserByID(ctx, uid)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return Identity{}, httpx.ErrUnauthorized("account no longer exists")
		}
		return Identity{}, err
	}
	mem, err := m.q.GetMembershipByUser(ctx, user.ID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return Identity{}, httpx.ErrUnauthorized("user has no farm")
		}
		return Identity{}, err
	}
	return Identity{
		Kind:     KindUser,
		UserID:   user.ID,
		Phone:    user.PhoneNumber,
		FarmID:   mem.FarmID,
		FarmRole: mem.Role,
		Label:    user.PhoneNumber,
		IsAdmin:  user.IsAdmin,
	}, nil
}

func (m *Middleware) doctorIdentity(ctx context.Context, claims *Claims) (Identity, error) {
	inv, err := m.q.GetActiveInvite(ctx, claims.Inv)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			// ended or expired → access revoked
			return Identity{}, httpx.ErrUnauthorized("this visit access has ended")
		}
		return Identity{}, err
	}
	return Identity{
		Kind:     KindDoctor,
		FarmID:   inv.FarmID,
		FarmRole: RoleDoctor,
		InviteID: inv.ID,
		Label:    inv.DoctorLabel,
	}, nil
}

// RequireAdmin gates app super-admin JSON endpoints; others get 403 (§7.3).
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

// RequireFarmAdmin gates farm-management endpoints (members, invites, billing) to
// the farm's admin.
func (m *Middleware) RequireFarmAdmin(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		id, ok := FromContext(r.Context())
		if !ok || id.FarmRole != RoleAdmin {
			httpx.WriteError(w, r, httpx.ErrForbidden("farm admin access required"))
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
