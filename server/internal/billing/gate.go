package billing

import (
	"net/http"

	"raai/internal/auth"
	"raai/internal/db/sqlc"
	"raai/internal/httpx"
)

// Gate is the subscription paywall (§7.2). It runs after auth on protected routes
// and keys off the owning farmer:
//   - a farmer caller must have an active subscription, else 402;
//   - a vet caller passes through here (they own nothing) — the per-farmer check
//     happens in the handlers, where the visit reveals which farmer's herd is touched.
type Gate struct {
	q *sqlc.Queries
}

func NewGate(q *sqlc.Queries) *Gate { return &Gate{q: q} }

func (g *Gate) Middleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		id, ok := auth.FromContext(r.Context())
		if !ok {
			httpx.WriteError(w, r, httpx.ErrUnauthorized("authentication required"))
			return
		}
		if id.Role == auth.RoleVet {
			next.ServeHTTP(w, r) // farmer-scoped check happens in the handler
			return
		}
		active, err := g.q.IsSubscriptionActive(r.Context(), id.UserID)
		if err != nil {
			httpx.WriteError(w, r, err)
			return
		}
		if !active {
			httpx.WriteError(w, r, httpx.ErrSubscriptionRequired("an active subscription is required"))
			return
		}
		next.ServeHTTP(w, r)
	})
}
