package billing

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

// Routes mounts /billing/* behind auth but NOT behind the paywall gate — an
// unpaid user must be able to see plans and pay (§7.2).
func (h *Handler) Routes(r chi.Router) {
	r.Get("/plans", h.plans)
	r.Get("/status", h.status)
	r.Post("/payments", h.submit)
	r.Get("/payments", h.listPayments)
}

func (h *Handler) plans(w http.ResponseWriter, r *http.Request) {
	httpx.WriteJSON(w, http.StatusOK, h.svc.Plans())
}

func (h *Handler) status(w http.ResponseWriter, r *http.Request) {
	res, err := h.svc.Status(r.Context(), auth.MustFarmID(r.Context()))
	if err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	httpx.WriteJSON(w, http.StatusOK, res)
}

type submitBody struct {
	Plan          string  `json:"plan"`
	InstapayRef   string  `json:"instapayRef"`
	AmountEGP     float64 `json:"amountEgp"`
	ScreenshotURL *string `json:"screenshotUrl"`
}

func (h *Handler) submit(w http.ResponseWriter, r *http.Request) {
	caller := auth.MustIdentity(r.Context())
	if caller.FarmRole != auth.RoleAdmin {
		httpx.WriteError(w, r, httpx.ErrForbidden("only the farm admin manages billing"))
		return
	}
	var in submitBody
	if err := httpx.DecodeJSON(r, &in); err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	p, err := h.svc.SubmitPayment(r.Context(), caller.FarmID, caller.UserID,
		in.Plan, strings.TrimSpace(in.InstapayRef), in.AmountEGP, in.ScreenshotURL)
	if err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	httpx.WriteJSON(w, http.StatusCreated, p)
}

func (h *Handler) listPayments(w http.ResponseWriter, r *http.Request) {
	caller := auth.MustIdentity(r.Context())
	if caller.FarmRole != auth.RoleAdmin {
		httpx.WriteError(w, r, httpx.ErrForbidden("only the farm admin manages billing"))
		return
	}
	page, err := httpx.ParsePage(r)
	if err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	res, err := h.svc.ListFarmPayments(r.Context(), caller.FarmID, page)
	if err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	httpx.WriteJSON(w, http.StatusOK, res)
}
