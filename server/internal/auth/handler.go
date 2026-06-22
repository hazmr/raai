package auth

import (
	"net/http"
	"strings"
	"time"

	"github.com/go-chi/chi/v5"
	"raai/internal/db/sqlc"
	"raai/internal/httpx"
)

// Handler exposes the auth + current-user HTTP endpoints (§6.2, §6.3).
type Handler struct {
	svc *Service
	q   *sqlc.Queries
}

func NewHandler(svc *Service, q *sqlc.Queries) *Handler {
	return &Handler{svc: svc, q: q}
}

// Routes mounts /auth/* (all public except logout, which needs auth applied by
// the caller's router composition).
func (h *Handler) Routes(r chi.Router) {
	r.Post("/register", h.register)
	r.Post("/login", h.login)
	r.Post("/refresh", h.refresh)
}

type credentials struct {
	PhoneNumber string `json:"phoneNumber"`
	Password    string `json:"password"`
	Role        string `json:"role"` // optional on register; "" → farmer
}

func (h *Handler) register(w http.ResponseWriter, r *http.Request) {
	var in credentials
	if err := httpx.DecodeJSON(r, &in); err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	if err := validateCredentials(in); err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	role := RoleFarmer
	if in.Role == RoleVet {
		role = RoleVet
	} else if in.Role != "" && in.Role != RoleFarmer {
		httpx.WriteError(w, r, httpx.ErrValidation("invalid role", map[string]string{"role": "must be 'farmer' or 'vet'"}))
		return
	}

	_, tokens, err := h.svc.Register(r.Context(), normalizePhone(in.PhoneNumber), in.Password, role)
	if err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	httpx.WriteJSON(w, http.StatusCreated, tokens)
}

func (h *Handler) login(w http.ResponseWriter, r *http.Request) {
	var in credentials
	if err := httpx.DecodeJSON(r, &in); err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	tokens, err := h.svc.Login(r.Context(), normalizePhone(in.PhoneNumber), in.Password)
	if err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	httpx.WriteJSON(w, http.StatusOK, tokens)
}

func (h *Handler) refresh(w http.ResponseWriter, r *http.Request) {
	var in struct {
		RefreshToken string `json:"refreshToken"`
	}
	if err := httpx.DecodeJSON(r, &in); err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	if strings.TrimSpace(in.RefreshToken) == "" {
		httpx.WriteError(w, r, httpx.ErrUnauthorized("refresh token is required"))
		return
	}
	tokens, err := h.svc.Refresh(r.Context(), in.RefreshToken)
	if err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	httpx.WriteJSON(w, http.StatusOK, tokens)
}

// Logout requires the auth middleware; clears the stored refresh token.
func (h *Handler) Logout(w http.ResponseWriter, r *http.Request) {
	if err := h.svc.Logout(r.Context(), MustUserID(r.Context())); err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	httpx.NoContent(w)
}

// userDTO is the §6.3 User shape (role added — additive within v1).
type userDTO struct {
	ID          int32     `json:"id"`
	PhoneNumber string    `json:"phoneNumber"`
	Role        string    `json:"role"`
	IsAdmin     bool      `json:"isAdmin"`
	CreatedAt   time.Time `json:"createdAt"`
}

// Me returns the current user (§6.3); requires the auth middleware.
func (h *Handler) Me(w http.ResponseWriter, r *http.Request) {
	user, err := h.q.GetUserByID(r.Context(), MustUserID(r.Context()))
	if err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	httpx.WriteJSON(w, http.StatusOK, userDTO{
		ID:          user.ID,
		PhoneNumber: user.PhoneNumber,
		Role:        user.Role,
		IsAdmin:     user.IsAdmin,
		CreatedAt:   httpx.TimeOf(user.CreatedAt),
	})
}

func validateCredentials(in credentials) error {
	fields := map[string]string{}
	if strings.TrimSpace(in.PhoneNumber) == "" {
		fields["phoneNumber"] = "is required"
	}
	if len(in.Password) < 6 {
		fields["password"] = "must be at least 6 characters"
	}
	if len(fields) > 0 {
		return httpx.ErrValidation("invalid credentials", fields)
	}
	return nil
}

func normalizePhone(p string) string { return strings.TrimSpace(p) }
