package billing

import (
	"net/http"

	"raai/internal/auth"
	"raai/internal/db/sqlc"
	"raai/internal/httpx"
)

// Gate is the subscription paywall (§7.2). It runs after auth on protected routes
// and keys off the caller's FARM: if the farm's subscription is inactive, nobody
// touching its herd gets through — neither members nor invited doctors. Billing,
// auth, and /me are mounted outside the gate so an unpaid admin can still pay.
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
		active, err := g.q.IsSubscriptionActive(r.Context(), id.FarmID)
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
