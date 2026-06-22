package visits

import (
	"net/http"

	"github.com/go-chi/chi/v5"
	"raai/internal/auth"
	"raai/internal/httpx"
)

type Handler struct {
	svc *Service
}

func NewHandler(svc *Service) *Handler { return &Handler{svc: svc} }

// Routes mounts /visits/* behind auth + the subscription gate.
func (h *Handler) Routes(r chi.Router) {
	r.Post("/", h.open)
	r.Get("/", h.list)
	r.Post("/{id}/close", h.close)
	r.Get("/{id}/animals", h.animals)
}

type openBody struct {
	VetPhone      *string `json:"vetPhone"`
	LocationType  string  `json:"locationType"`
	LocationLabel *string `json:"locationLabel"`
}

func (h *Handler) open(w http.ResponseWriter, r *http.Request) {
	caller, _ := auth.FromContext(r.Context())
	if caller.Role != auth.RoleFarmer {
		httpx.WriteError(w, r, httpx.ErrForbidden("only a farmer can open a visit"))
		return
	}
	var in openBody
	if err := httpx.DecodeJSON(r, &in); err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	v, err := h.svc.Open(r.Context(), caller.UserID, in.VetPhone, in.LocationType, in.LocationLabel)
	if err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	httpx.WriteJSON(w, http.StatusCreated, v)
}

func (h *Handler) list(w http.ResponseWriter, r *http.Request) {
	caller, _ := auth.FromContext(r.Context())
	page, err := httpx.ParsePage(r)
	if err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	var res httpx.List[DTO]
	if caller.Role == auth.RoleVet {
		var status *string
		if s := r.URL.Query().Get("status"); s != "" {
			status = &s
		}
		res, err = h.svc.ListForVet(r.Context(), caller.UserID, status, page)
	} else {
		res, err = h.svc.ListForFarmer(r.Context(), caller.UserID, page)
	}
	if err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	httpx.WriteJSON(w, http.StatusOK, res)
}

func (h *Handler) close(w http.ResponseWriter, r *http.Request) {
	caller, _ := auth.FromContext(r.Context())
	if caller.Role != auth.RoleFarmer {
		httpx.WriteError(w, r, httpx.ErrForbidden("only the farmer can close a visit"))
		return
	}
	id, err := httpx.PathInt(r, "id")
	if err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	v, err := h.svc.Close(r.Context(), caller.UserID, id)
	if err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	httpx.WriteJSON(w, http.StatusOK, v)
}

func (h *Handler) animals(w http.ResponseWriter, r *http.Request) {
	caller, _ := auth.FromContext(r.Context())
	if caller.Role != auth.RoleVet {
		httpx.WriteError(w, r, httpx.ErrForbidden("only an assigned vet can browse a visit's herd"))
		return
	}
	id, err := httpx.PathInt(r, "id")
	if err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	page, err := httpx.ParsePage(r)
	if err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	res, err := h.svc.AnimalsForVisit(r.Context(), caller.UserID, id, page)
	if err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	httpx.WriteJSON(w, http.StatusOK, res)
}
