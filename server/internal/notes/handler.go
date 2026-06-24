package notes

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

// Routes mounts the notes sub-resource; the caller mounts this under
// /animals/{animalId}/notes behind auth + the subscription gate.
func (h *Handler) Routes(r chi.Router) {
	r.Get("/", h.list)
	r.Post("/", h.create)
	r.Get("/{noteID}", h.get)
	r.Patch("/{noteID}", h.update)
	r.Delete("/{noteID}", h.delete)
}

type noteBody struct {
	Body string `json:"body"`
}

func (h *Handler) list(w http.ResponseWriter, r *http.Request) {
	animalID, err := httpx.PathInt(r, "animalID")
	if err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	page, err := httpx.ParsePage(r)
	if err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	caller, _ := auth.FromContext(r.Context())
	res, err := h.svc.List(r.Context(), caller, animalID, page)
	if err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	httpx.WriteJSON(w, http.StatusOK, res)
}

func (h *Handler) get(w http.ResponseWriter, r *http.Request) {
	animalID, err := httpx.PathInt(r, "animalID")
	if err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	noteID, err := httpx.PathInt(r, "noteID")
	if err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	caller, _ := auth.FromContext(r.Context())
	n, err := h.svc.Get(r.Context(), caller, animalID, noteID)
	if err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	httpx.WriteJSON(w, http.StatusOK, n)
}

func (h *Handler) create(w http.ResponseWriter, r *http.Request) {
	animalID, err := httpx.PathInt(r, "animalID")
	if err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	var in noteBody
	if err := httpx.DecodeJSON(r, &in); err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	if strings.TrimSpace(in.Body) == "" {
		httpx.WriteError(w, r, httpx.ErrValidation("note body is required", map[string]string{"body": "is required"}))
		return
	}
	caller, _ := auth.FromContext(r.Context())
	n, err := h.svc.Create(r.Context(), caller, animalID, in.Body)
	if err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	httpx.WriteJSON(w, http.StatusCreated, n)
}

func (h *Handler) update(w http.ResponseWriter, r *http.Request) {
	animalID, err := httpx.PathInt(r, "animalID")
	if err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	noteID, err := httpx.PathInt(r, "noteID")
	if err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	var in noteBody
	if err := httpx.DecodeJSON(r, &in); err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	if strings.TrimSpace(in.Body) == "" {
		httpx.WriteError(w, r, httpx.ErrValidation("note body is required", map[string]string{"body": "is required"}))
		return
	}
	caller, _ := auth.FromContext(r.Context())
	n, err := h.svc.Update(r.Context(), caller, animalID, noteID, in.Body)
	if err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	httpx.WriteJSON(w, http.StatusOK, n)
}

func (h *Handler) delete(w http.ResponseWriter, r *http.Request) {
	animalID, err := httpx.PathInt(r, "animalID")
	if err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	noteID, err := httpx.PathInt(r, "noteID")
	if err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	caller, _ := auth.FromContext(r.Context())
	if err := h.svc.Delete(r.Context(), caller, animalID, noteID); err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	httpx.NoContent(w)
}
