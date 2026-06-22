// Package server wires config + db pool into the full HTTP handler: middleware
// stack, the versioned /api/v1 contract, and the /admin dashboard (§3, §6, §8).
package server

import (
	"net/http"

	"github.com/go-chi/chi/v5"
	chimw "github.com/go-chi/chi/v5/middleware"
	"github.com/jackc/pgx/v5/pgxpool"

	"raai/internal/admin"
	"raai/internal/animals"
	"raai/internal/auth"
	"raai/internal/billing"
	"raai/internal/config"
	"raai/internal/db/sqlc"
	"raai/internal/httpx"
	mw "raai/internal/middleware"
	"raai/internal/notes"
	"raai/internal/visits"
)

// App bundles the built handler and the query layer (the latter so background
// jobs like the expiry sweep can reuse it).
type App struct {
	Handler http.Handler
	Queries *sqlc.Queries
}

func New(cfg *config.Config, pool *pgxpool.Pool) (*App, error) {
	q := sqlc.New(pool)

	// Services
	tokens := auth.NewTokenManager(cfg.JWTKey, cfg.JWTIssuer, cfg.JWTAudience, cfg.AccessTokenTTL)
	authMW := auth.NewMiddleware(tokens, q)
	authSvc := auth.NewService(q, tokens, cfg.RefreshTokenTTL)
	authH := auth.NewHandler(authSvc, q)

	notesSvc := notes.NewService(q)
	notesH := notes.NewHandler(notesSvc)
	animalsSvc := animals.NewService(q, notesSvc)
	animalsH := animals.NewHandler(animalsSvc)
	visitsSvc := visits.NewService(q, animalsSvc)
	visitsH := visits.NewHandler(visitsSvc)

	billingSvc := billing.NewService(q, billing.Config{
		InstapayIPA:     cfg.InstapayIPA,
		DisplayName:     cfg.InstapayDisplayName,
		PriceMonthlyEGP: cfg.PriceMonthlyEGP,
		PriceYearlyEGP:  cfg.PriceYearlyEGP,
	})
	billingH := billing.NewHandler(billingSvc)
	gate := billing.NewGate(q)

	adminSvc := admin.NewService(pool, q)
	adminJSON := admin.NewJSONHandler(adminSvc)
	dashboard, err := admin.NewDashboard(adminSvc, q, cfg.JWTKey, cfg.SecureCookies)
	if err != nil {
		return nil, err
	}

	loginLimiter := mw.NewRateLimiter(1, 8)  // /admin login + /auth: ~1 rps, burst 8
	apiLimiter := mw.NewRateLimiter(20, 100) // general API budget per IP

	r := chi.NewRouter()
	r.Use(chimw.RequestID)
	r.Use(chimw.RealIP)
	r.Use(mw.RequestLogger)
	r.Use(mw.Recoverer)

	// Platform health probes (§9).
	r.Get("/healthz", func(w http.ResponseWriter, r *http.Request) {
		httpx.WriteJSON(w, http.StatusOK, map[string]string{"status": "ok"})
	})
	r.Get("/readyz", func(w http.ResponseWriter, r *http.Request) {
		if err := pool.Ping(r.Context()); err != nil {
			httpx.WriteError(w, r, httpx.ErrInternal())
			return
		}
		httpx.WriteJSON(w, http.StatusOK, map[string]string{"status": "ready"})
	})

	r.Route("/api/v1", func(r chi.Router) {
		r.Use(apiLimiter.Middleware)

		// Public auth endpoints (extra rate limiting on credential checks).
		r.Group(func(r chi.Router) {
			r.Use(loginLimiter.Middleware)
			r.Route("/auth", authH.Routes)
		})

		// Authenticated, NOT behind the paywall (§7.2: auth, me, billing, admin).
		r.Group(func(r chi.Router) {
			r.Use(authMW.Authenticator)
			r.Post("/auth/logout", authH.Logout)
			r.Get("/me", authH.Me)
			r.Route("/billing", billingH.Routes)
			r.Route("/admin", func(r chi.Router) {
				r.Use(authMW.RequireAdmin)
				adminJSON.Routes(r)
			})

			// Authenticated AND behind the subscription gate.
			r.Group(func(r chi.Router) {
				r.Use(gate.Middleware)
				r.Route("/animals", func(r chi.Router) {
					animalsH.Routes(r)
					r.Route("/{animalID}/notes", notesH.Routes)
				})
				r.Route("/visits", visitsH.Routes)
			})
		})
	})

	// Browser admin dashboard (cookie sessions, separate transport).
	r.Route("/admin", func(r chi.Router) {
		r.Use(loginLimiter.Middleware)
		dashboard.Routes(r)
	})

	return &App{Handler: r, Queries: q}, nil
}
