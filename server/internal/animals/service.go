// Package animals implements the animals resource (§6.4) with mandatory user
// scoping and optional embedded notes.
package animals

import (
	"context"
	"errors"
	"time"

	"github.com/jackc/pgx/v5"
	"raai/internal/auth"
	"raai/internal/db"
	"raai/internal/db/sqlc"
	"raai/internal/httpx"
	"raai/internal/notes"
)

type Service struct {
	q     *sqlc.Queries
	notes *notes.Service
}

func NewService(q *sqlc.Queries, n *notes.Service) *Service {
	return &Service{q: q, notes: n}
}

// DTO is the §6.4 Animal shape; notes are embedded only on ?include=notes.
type DTO struct {
	ID        int32       `json:"id"`
	Barcode   string      `json:"barcode"`
	NoteCount int64       `json:"noteCount"`
	CreatedAt time.Time   `json:"createdAt"`
	UpdatedAt time.Time   `json:"updatedAt"`
	Notes     []notes.DTO `json:"notes,omitempty"`
}

func (s *Service) List(ctx context.Context, caller auth.Identity, page httpx.Page, barcode string, include bool) (httpx.List[DTO], error) {
	// Barcode lookup is a filter returning a 0/1-element list (§6.4).
	if barcode != "" {
		a, err := s.q.GetAnimalByBarcode(ctx, sqlc.GetAnimalByBarcodeParams{Barcode: barcode, UserID: caller.UserID})
		if err != nil {
			if errors.Is(err, pgx.ErrNoRows) {
				return httpx.List[DTO]{Data: []DTO{}}, nil
			}
			return httpx.List[DTO]{}, err
		}
		dto := DTO{ID: a.ID, Barcode: a.Barcode, NoteCount: a.NoteCount, CreatedAt: httpx.TimeOf(a.CreatedAt), UpdatedAt: httpx.TimeOf(a.UpdatedAt)}
		if include {
			if err := s.attachNotes(ctx, caller, &dto); err != nil {
				return httpx.List[DTO]{}, err
			}
		}
		return httpx.List[DTO]{Data: []DTO{dto}}, nil
	}

	rows, err := s.q.ListAnimals(ctx, sqlc.ListAnimalsParams{
		UserID:     caller.UserID,
		CursorTime: page.CursorTime(),
		CursorID:   page.CursorID(),
		Lim:        page.Limit,
	})
	if err != nil {
		return httpx.List[DTO]{}, err
	}
	out := httpx.List[DTO]{Data: make([]DTO, 0, len(rows))}
	for _, a := range rows {
		dto := DTO{ID: a.ID, Barcode: a.Barcode, NoteCount: a.NoteCount, CreatedAt: httpx.TimeOf(a.CreatedAt), UpdatedAt: httpx.TimeOf(a.UpdatedAt)}
		if include {
			if err := s.attachNotes(ctx, caller, &dto); err != nil {
				return httpx.List[DTO]{}, err
			}
		}
		out.Data = append(out.Data, dto)
	}
	if int32(len(rows)) == page.Limit && page.Limit > 0 {
		last := rows[len(rows)-1]
		c := httpx.EncodeCursor(last.CreatedAt.Time, last.ID)
		out.NextCursor = &c
	}
	return out, nil
}

// ListForOwner lists a specific owner's herd, used when a vet browses the
// farmer's animals during a visit (§6.8). Access is verified by the caller.
func (s *Service) ListForOwner(ctx context.Context, ownerID int32, page httpx.Page) (httpx.List[DTO], error) {
	rows, err := s.q.ListAnimals(ctx, sqlc.ListAnimalsParams{
		UserID:     ownerID,
		CursorTime: page.CursorTime(),
		CursorID:   page.CursorID(),
		Lim:        page.Limit,
	})
	if err != nil {
		return httpx.List[DTO]{}, err
	}
	out := httpx.List[DTO]{Data: make([]DTO, 0, len(rows))}
	for _, a := range rows {
		out.Data = append(out.Data, DTO{ID: a.ID, Barcode: a.Barcode, NoteCount: a.NoteCount, CreatedAt: httpx.TimeOf(a.CreatedAt), UpdatedAt: httpx.TimeOf(a.UpdatedAt)})
	}
	if int32(len(rows)) == page.Limit && page.Limit > 0 {
		last := rows[len(rows)-1]
		c := httpx.EncodeCursor(last.CreatedAt.Time, last.ID)
		out.NextCursor = &c
	}
	return out, nil
}

func (s *Service) Get(ctx context.Context, caller auth.Identity, id int32, include bool) (DTO, error) {
	a, err := s.q.GetAnimal(ctx, sqlc.GetAnimalParams{ID: id, UserID: caller.UserID})
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return DTO{}, httpx.ErrNotFound("animal not found")
		}
		return DTO{}, err
	}
	dto := DTO{ID: a.ID, Barcode: a.Barcode, NoteCount: a.NoteCount, CreatedAt: httpx.TimeOf(a.CreatedAt), UpdatedAt: httpx.TimeOf(a.UpdatedAt)}
	if include {
		if err := s.attachNotes(ctx, caller, &dto); err != nil {
			return DTO{}, err
		}
	}
	return dto, nil
}

// Create adds an animal. A farmer creates under their own id; a vet creates under
// the farmer of an open visit they're assigned to (scanning a new ear tag, §4.3).
func (s *Service) Create(ctx context.Context, caller auth.Identity, barcode string, visitID *int32) (DTO, error) {
	owner := caller.UserID
	if caller.Role == auth.RoleVet {
		if visitID == nil {
			return DTO{}, httpx.ErrValidation("a vet must create animals inside a visit", map[string]string{"visitId": "is required"})
		}
		visit, err := s.q.GetOpenVisitForVet(ctx, sqlc.GetOpenVisitForVetParams{ID: *visitID, VetID: &caller.UserID})
		if err != nil {
			if errors.Is(err, pgx.ErrNoRows) {
				return DTO{}, httpx.ErrForbidden("no open visit assigned to you with this id")
			}
			return DTO{}, err
		}
		active, err := s.q.IsSubscriptionActive(ctx, visit.FarmerID)
		if err != nil {
			return DTO{}, err
		}
		if !active {
			return DTO{}, httpx.ErrSubscriptionRequired("the herd owner's subscription is inactive")
		}
		owner = visit.FarmerID
	}

	a, err := s.q.CreateAnimal(ctx, sqlc.CreateAnimalParams{Barcode: barcode, UserID: owner})
	if err != nil {
		if db.IsUniqueViolation(err) {
			return DTO{}, httpx.ErrConflict("an animal with this barcode already exists")
		}
		return DTO{}, err
	}
	return DTO{ID: a.ID, Barcode: a.Barcode, NoteCount: 0, CreatedAt: httpx.TimeOf(a.CreatedAt), UpdatedAt: httpx.TimeOf(a.UpdatedAt)}, nil
}

// Update changes an animal's barcode (farmer-owned only).
func (s *Service) Update(ctx context.Context, caller auth.Identity, id int32, barcode string) (DTO, error) {
	a, err := s.q.UpdateAnimal(ctx, sqlc.UpdateAnimalParams{Barcode: barcode, ID: id, UserID: caller.UserID})
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return DTO{}, httpx.ErrNotFound("animal not found")
		}
		if db.IsUniqueViolation(err) {
			return DTO{}, httpx.ErrConflict("an animal with this barcode already exists")
		}
		return DTO{}, err
	}
	// Recompute note count for an accurate response.
	full, err := s.q.GetAnimal(ctx, sqlc.GetAnimalParams{ID: a.ID, UserID: caller.UserID})
	if err != nil {
		return DTO{}, err
	}
	return DTO{ID: full.ID, Barcode: full.Barcode, NoteCount: full.NoteCount, CreatedAt: httpx.TimeOf(full.CreatedAt), UpdatedAt: httpx.TimeOf(full.UpdatedAt)}, nil
}

func (s *Service) Delete(ctx context.Context, caller auth.Identity, id int32) error {
	rows, err := s.q.DeleteAnimal(ctx, sqlc.DeleteAnimalParams{ID: id, UserID: caller.UserID})
	if err != nil {
		return err
	}
	if rows == 0 {
		return httpx.ErrNotFound("animal not found")
	}
	return nil
}

func (s *Service) attachNotes(ctx context.Context, caller auth.Identity, dto *DTO) error {
	embedded, err := s.notes.EmbedFirstPage(ctx, caller, dto.ID)
	if err != nil {
		return err
	}
	dto.Notes = embedded
	return nil
}
