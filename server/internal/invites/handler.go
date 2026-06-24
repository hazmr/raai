package invites

import (
	"net/http"
	"strings"
	"time"

	"github.com/go-chi/chi/v5"
	"raai/internal/auth"
	"raai/internal/httpx"
)

type Handler struct {
	svc *Service
}

func NewHandler(svc *Service) *Handler { return &Handler{svc: svc} }

// Routes mounts the farm-admin invite management under /invites (caller applies
// auth + gate + RequireFarmAdmin).
func (h *Handler) Routes(r chi.Router) {
	r.Post("/", h.create)
	r.Get("/", h.list)
	r.Post("/{id}/end", h.end)
}

type createBody struct {
	DoctorLabel string     `json:"doctorLabel"`
	ExpiresAt   *time.Time `json:"expiresAt"`
}

func (h *Handler) create(w http.ResponseWriter, r *http.Request) {
	caller := auth.MustIdentity(r.Context())
	var in createBody
	if err := httpx.DecodeJSON(r, &in); err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	if strings.TrimSpace(in.DoctorLabel) == "" {
		httpx.WriteError(w, r, httpx.ErrValidation("doctor name is required", map[string]string{"doctorLabel": "is required"}))
		return
	}
	inv, err := h.svc.Create(r.Context(), caller.FarmID, caller.UserID, strings.TrimSpace(in.DoctorLabel), in.ExpiresAt)
	if err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	httpx.WriteJSON(w, http.StatusCreated, inv)
}

func (h *Handler) list(w http.ResponseWriter, r *http.Request) {
	caller := auth.MustIdentity(r.Context())
	rows, err := h.svc.ListForFarm(r.Context(), caller.FarmID)
	if err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	httpx.WriteJSON(w, http.StatusOK, httpx.List[DTO]{Data: rows})
}

func (h *Handler) end(w http.ResponseWriter, r *http.Request) {
	caller := auth.MustIdentity(r.Context())
	id, err := httpx.PathInt(r, "id")
	if err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	inv, err := h.svc.End(r.Context(), caller.FarmID, id, caller.UserID)
	if err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	httpx.WriteJSON(w, http.StatusOK, inv)
}

// Redeem is the PUBLIC doctor entry point: trade a QR secret for a session.
func (h *Handler) Redeem(w http.ResponseWriter, r *http.Request) {
	var in struct {
		Token string `json:"token"`
	}
	if err := httpx.DecodeJSON(r, &in); err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	if strings.TrimSpace(in.Token) == "" {
		httpx.WriteError(w, r, httpx.ErrUnauthorized("a visit code is required"))
		return
	}
	sess, err := h.svc.Redeem(r.Context(), strings.TrimSpace(in.Token))
	if err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	httpx.WriteJSON(w, http.StatusOK, sess)
}
