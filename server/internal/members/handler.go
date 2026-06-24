package members

import (
	"net/http"
	"strings"

	"github.com/go-chi/chi/v5"
	"raai/internal/auth"
	"raai/internal/httpx"
)

type Handler struct {
	svc *Service
}

func NewHandler(svc *Service) *Handler { return &Handler{svc: svc} }

// Routes mounts /farm/members (caller applies auth + RequireFarmAdmin).
func (h *Handler) Routes(r chi.Router) {
	r.Get("/", h.list)
	r.Post("/", h.add)
	r.Delete("/{userID}", h.remove)
}

func (h *Handler) list(w http.ResponseWriter, r *http.Request) {
	caller := auth.MustIdentity(r.Context())
	rows, err := h.svc.List(r.Context(), caller.FarmID)
	if err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	httpx.WriteJSON(w, http.StatusOK, httpx.List[DTO]{Data: rows})
}

func (h *Handler) add(w http.ResponseWriter, r *http.Request) {
	caller := auth.MustIdentity(r.Context())
	var in struct {
		PhoneNumber string `json:"phoneNumber"`
		Password    string `json:"password"`
	}
	if err := httpx.DecodeJSON(r, &in); err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	fields := map[string]string{}
	if strings.TrimSpace(in.PhoneNumber) == "" {
		fields["phoneNumber"] = "is required"
	}
	if len(in.Password) < 6 {
		fields["password"] = "must be at least 6 characters"
	}
	if len(fields) > 0 {
		httpx.WriteError(w, r, httpx.ErrValidation("invalid member", fields))
		return
	}
	m, err := h.svc.Add(r.Context(), caller.FarmID, strings.TrimSpace(in.PhoneNumber), in.Password)
	if err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	httpx.WriteJSON(w, http.StatusCreated, m)
}

func (h *Handler) remove(w http.ResponseWriter, r *http.Request) {
	caller := auth.MustIdentity(r.Context())
	uid, err := httpx.PathInt(r, "userID")
	if err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	if err := h.svc.Remove(r.Context(), caller.FarmID, uid); err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	httpx.NoContent(w)
}
