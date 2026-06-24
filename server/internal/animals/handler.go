package animals

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

// Routes mounts /animals/* behind auth + the subscription gate. Notes are mounted
// separately by the caller under /animals/{animalId}/notes.
func (h *Handler) Routes(r chi.Router) {
	r.Get("/", h.list)
	r.Post("/", h.create)
	r.Get("/{animalID}", h.get)
	r.Patch("/{animalID}", h.update)
	r.Delete("/{animalID}", h.delete)
}

func wantsNotes(r *http.Request) bool {
	return strings.Contains(r.URL.Query().Get("include"), "notes")
}

func (h *Handler) list(w http.ResponseWriter, r *http.Request) {
	page, err := httpx.ParsePage(r)
	if err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	caller, _ := auth.FromContext(r.Context())
	res, err := h.svc.List(r.Context(), caller, page, r.URL.Query().Get("barcode"), wantsNotes(r))
	if err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	httpx.WriteJSON(w, http.StatusOK, res)
}

func (h *Handler) get(w http.ResponseWriter, r *http.Request) {
	id, err := httpx.PathInt(r, "animalID")
	if err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	caller, _ := auth.FromContext(r.Context())
	a, err := h.svc.Get(r.Context(), caller, id, wantsNotes(r))
	if err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	httpx.WriteJSON(w, http.StatusOK, a)
}

type animalBody struct {
	Barcode string `json:"barcode"`
}

func (h *Handler) create(w http.ResponseWriter, r *http.Request) {
	var in animalBody
	if err := httpx.DecodeJSON(r, &in); err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	if strings.TrimSpace(in.Barcode) == "" {
		httpx.WriteError(w, r, httpx.ErrValidation("barcode is required", map[string]string{"barcode": "is required"}))
		return
	}
	caller, _ := auth.FromContext(r.Context())
	a, err := h.svc.Create(r.Context(), caller, strings.TrimSpace(in.Barcode))
	if err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	httpx.WriteJSON(w, http.StatusCreated, a)
}

func (h *Handler) update(w http.ResponseWriter, r *http.Request) {
	id, err := httpx.PathInt(r, "animalID")
	if err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	var in animalBody
	if err := httpx.DecodeJSON(r, &in); err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	if strings.TrimSpace(in.Barcode) == "" {
		httpx.WriteError(w, r, httpx.ErrValidation("barcode is required", map[string]string{"barcode": "is required"}))
		return
	}
	caller, _ := auth.FromContext(r.Context())
	a, err := h.svc.Update(r.Context(), caller, id, strings.TrimSpace(in.Barcode))
	if err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	httpx.WriteJSON(w, http.StatusOK, a)
}

func (h *Handler) delete(w http.ResponseWriter, r *http.Request) {
	id, err := httpx.PathInt(r, "animalID")
	if err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	caller, _ := auth.FromContext(r.Context())
	if err := h.svc.Delete(r.Context(), caller, id); err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	httpx.NoContent(w)
}
