package admin

import (
	"net/http"

	"github.com/go-chi/chi/v5"
	"raai/internal/auth"
	"raai/internal/httpx"
)

// JSONHandler exposes the §7.3 admin endpoints under /api/v1/admin, behind auth +
// RequireAdmin. They share the Service with the dashboard.
type JSONHandler struct {
	svc *Service
}

func NewJSONHandler(svc *Service) *JSONHandler { return &JSONHandler{svc: svc} }

func (h *JSONHandler) Routes(r chi.Router) {
	r.Get("/payments", h.listPayments)
	r.Post("/payments/{id}/confirm", h.confirm)
	r.Post("/payments/{id}/reject", h.reject)
}

func (h *JSONHandler) listPayments(w http.ResponseWriter, r *http.Request) {
	page, err := httpx.ParsePage(r)
	if err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	var status *string
	if s := r.URL.Query().Get("status"); s != "" {
		status = &s
	}
	res, err := h.svc.ListPayments(r.Context(), status, page)
	if err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	httpx.WriteJSON(w, http.StatusOK, res)
}

func (h *JSONHandler) confirm(w http.ResponseWriter, r *http.Request) {
	id, err := httpx.PathInt(r, "id")
	if err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	p, err := h.svc.ConfirmPayment(r.Context(), auth.MustUserID(r.Context()), id)
	if err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	httpx.WriteJSON(w, http.StatusOK, p)
}

func (h *JSONHandler) reject(w http.ResponseWriter, r *http.Request) {
	id, err := httpx.PathInt(r, "id")
	if err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	var in struct {
		Note string `json:"note"`
	}
	if err := httpx.DecodeJSON(r, &in); err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	p, err := h.svc.RejectPayment(r.Context(), auth.MustUserID(r.Context()), id, in.Note)
	if err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	httpx.WriteJSON(w, http.StatusOK, p)
}
