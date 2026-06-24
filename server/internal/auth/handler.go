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

// Routes mounts /auth/* (public except logout, applied by the caller's composition).
func (h *Handler) Routes(r chi.Router) {
	r.Post("/register", h.register)
	r.Post("/login", h.login)
	r.Post("/refresh", h.refresh)
}

type credentials struct {
	PhoneNumber string `json:"phoneNumber"`
	Password    string `json:"password"`
	FarmName    string `json:"farmName"`
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
	farmName := strings.TrimSpace(in.FarmName)
	if farmName == "" {
		farmName = "مزرعة " + normalizePhone(in.PhoneNumber)
	}
	// Registration always creates a farm with the user as its admin. Doctors never
	// register — they redeem a QR invite (see the invites handler).
	_, _, tokens, err := h.svc.Register(r.Context(), normalizePhone(in.PhoneNumber), in.Password, farmName)
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

// farmDTO and userDTO make up the §6.3 current-user payload.
type farmDTO struct {
	ID   int32  `json:"id"`
	Name string `json:"name"`
}

type meDTO struct {
	ID          int32     `json:"id"`
	PhoneNumber string    `json:"phoneNumber"`
	IsAdmin     bool      `json:"isAdmin"`
	CreatedAt   time.Time `json:"createdAt"`
	Farm        farmDTO   `json:"farm"`
	FarmRole    string    `json:"farmRole"` // admin | farmer
}

// Me returns the current user with their farm context (§6.3).
func (h *Handler) Me(w http.ResponseWriter, r *http.Request) {
	id := MustIdentity(r.Context())
	user, err := h.q.GetUserByID(r.Context(), id.UserID)
	if err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	farm, err := h.q.GetFarm(r.Context(), id.FarmID)
	if err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	httpx.WriteJSON(w, http.StatusOK, meDTO{
		ID:          user.ID,
		PhoneNumber: user.PhoneNumber,
		IsAdmin:     user.IsAdmin,
		CreatedAt:   httpx.TimeOf(user.CreatedAt),
		Farm:        farmDTO{ID: farm.ID, Name: farm.Name},
		FarmRole:    id.FarmRole,
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
