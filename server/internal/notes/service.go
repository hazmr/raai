// Package notes implements the animal-notes sub-resource (§6.5) including the
// farmer/vet authorization rules (§4.3).
package notes

import (
	"context"
	"errors"
	"time"

	"github.com/jackc/pgx/v5"
	"raai/internal/auth"
	"raai/internal/db/sqlc"
	"raai/internal/httpx"
)

type Service struct {
	q *sqlc.Queries
}

func NewService(q *sqlc.Queries) *Service { return &Service{q: q} }

// DTO is the §6.5 Note shape; the DB column `notes` is exposed as `body`.
type DTO struct {
	ID         int32     `json:"id"`
	AnimalID   int32     `json:"animalId"`
	Body       string    `json:"body"`
	AuthorID   int32     `json:"authorId"`
	AuthorRole string    `json:"authorRole"`
	VisitID    *int32    `json:"visitId"`
	CreatedAt  time.Time `json:"createdAt"`
	UpdatedAt  time.Time `json:"updatedAt"`
}

func toDTO(n sqlc.AnimalNote) DTO {
	return DTO{
		ID:         n.ID,
		AnimalID:   n.AnimalID,
		Body:       n.Notes,
		AuthorID:   n.AuthorID,
		AuthorRole: n.AuthorRole,
		VisitID:    n.VisitID,
		CreatedAt:  httpx.TimeOf(n.CreatedAt),
		UpdatedAt:  httpx.TimeOf(n.UpdatedAt),
	}
}

// resolveReadOwner returns the farmer id that owns animalID, enforcing access:
// a farmer must own it; a vet must hold an open visit with the owner and that
// owner's subscription must be active. Failures map to 404 to avoid leaking ids.
func (s *Service) resolveReadOwner(ctx context.Context, caller auth.Identity, animalID int32) (int32, error) {
	if caller.Role == auth.RoleVet {
		owner, err := s.q.GetAnimalOwner(ctx, animalID)
		if err != nil {
			if errors.Is(err, pgx.ErrNoRows) {
				return 0, httpx.ErrNotFound("animal not found")
			}
			return 0, err
		}
		has, err := s.q.VetHasOpenVisitWithFarmer(ctx, sqlc.VetHasOpenVisitWithFarmerParams{
			VetID: &caller.UserID, FarmerID: owner.UserID,
		})
		if err != nil {
			return 0, err
		}
		if !has {
			return 0, httpx.ErrNotFound("animal not found")
		}
		if err := s.requireFarmerActive(ctx, owner.UserID); err != nil {
			return 0, err
		}
		return owner.UserID, nil
	}
	// Farmer: ownership is enforced by the scoped GetAnimal.
	if _, err := s.q.GetAnimal(ctx, sqlc.GetAnimalParams{ID: animalID, UserID: caller.UserID}); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return 0, httpx.ErrNotFound("animal not found")
		}
		return 0, err
	}
	return caller.UserID, nil
}

func (s *Service) requireFarmerActive(ctx context.Context, farmerID int32) error {
	active, err := s.q.IsSubscriptionActive(ctx, farmerID)
	if err != nil {
		return err
	}
	if !active {
		return httpx.ErrSubscriptionRequired("the herd owner's subscription is inactive")
	}
	return nil
}

func (s *Service) List(ctx context.Context, caller auth.Identity, animalID int32, page httpx.Page) (httpx.List[DTO], error) {
	owner, err := s.resolveReadOwner(ctx, caller, animalID)
	if err != nil {
		return httpx.List[DTO]{}, err
	}
	rows, err := s.q.ListNotes(ctx, sqlc.ListNotesParams{
		AnimalID:   animalID,
		OwnerID:    owner,
		CursorTime: page.CursorTime(),
		CursorID:   page.CursorID(),
		Lim:        page.Limit,
	})
	if err != nil {
		return httpx.List[DTO]{}, err
	}
	return paginate(rows, page.Limit), nil
}

func (s *Service) Get(ctx context.Context, caller auth.Identity, animalID, noteID int32) (DTO, error) {
	owner, err := s.resolveReadOwner(ctx, caller, animalID)
	if err != nil {
		return DTO{}, err
	}
	n, err := s.q.GetNote(ctx, sqlc.GetNoteParams{ID: noteID, AnimalID: animalID, OwnerID: owner})
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return DTO{}, httpx.ErrNotFound("note not found")
		}
		return DTO{}, err
	}
	return toDTO(n), nil
}

// Create writes a note, enforcing the §6.5 rule that a vet must supply an open
// visit they're assigned to and the farmer (the visit owner) must be active.
func (s *Service) Create(ctx context.Context, caller auth.Identity, animalID int32, body string, visitID *int32) (DTO, error) {
	owner, role, vid, err := s.resolveWriteContext(ctx, caller, animalID, visitID)
	if err != nil {
		return DTO{}, err
	}
	// Confirm the animal belongs to the resolved owner before writing.
	if _, err := s.q.GetAnimal(ctx, sqlc.GetAnimalParams{ID: animalID, UserID: owner}); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return DTO{}, httpx.ErrNotFound("animal not found")
		}
		return DTO{}, err
	}
	n, err := s.q.CreateNote(ctx, sqlc.CreateNoteParams{
		AnimalID:   animalID,
		Notes:      body,
		AuthorID:   caller.UserID,
		AuthorRole: role,
		VisitID:    vid,
	})
	if err != nil {
		return DTO{}, err
	}
	return toDTO(n), nil
}

func (s *Service) resolveWriteContext(ctx context.Context, caller auth.Identity, animalID int32, visitID *int32) (owner int32, role string, vid *int32, err error) {
	if caller.Role == auth.RoleVet {
		if visitID == nil {
			return 0, "", nil, httpx.ErrValidation("a vet must write notes inside a visit", map[string]string{"visitId": "is required"})
		}
		visit, err := s.q.GetOpenVisitForVet(ctx, sqlc.GetOpenVisitForVetParams{ID: *visitID, VetID: &caller.UserID})
		if err != nil {
			if errors.Is(err, pgx.ErrNoRows) {
				return 0, "", nil, httpx.ErrForbidden("no open visit assigned to you with this id")
			}
			return 0, "", nil, err
		}
		if err := s.requireFarmerActive(ctx, visit.FarmerID); err != nil {
			return 0, "", nil, err
		}
		return visit.FarmerID, auth.RoleVet, visitID, nil
	}
	// Farmer: visit is optional; if given it must be theirs and open.
	if visitID != nil {
		visit, err := s.q.GetVisitForFarmer(ctx, sqlc.GetVisitForFarmerParams{ID: *visitID, FarmerID: caller.UserID})
		if err != nil {
			if errors.Is(err, pgx.ErrNoRows) {
				return 0, "", nil, httpx.ErrNotFound("visit not found")
			}
			return 0, "", nil, err
		}
		if visit.Status != "open" {
			return 0, "", nil, httpx.ErrValidation("visit is closed", map[string]string{"visitId": "must reference an open visit"})
		}
	}
	return caller.UserID, auth.RoleFarmer, visitID, nil
}

// Update edits a note; only the author may change it (and a vet only while their
// visit remains open, enforced via resolveReadOwner).
func (s *Service) Update(ctx context.Context, caller auth.Identity, animalID, noteID int32, body string) (DTO, error) {
	if _, err := s.resolveReadOwner(ctx, caller, animalID); err != nil {
		return DTO{}, err
	}
	n, err := s.q.UpdateNote(ctx, sqlc.UpdateNoteParams{
		Notes:    body,
		ID:       noteID,
		AnimalID: animalID,
		AuthorID: caller.UserID,
	})
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return DTO{}, httpx.ErrNotFound("note not found or not yours to edit")
		}
		return DTO{}, err
	}
	return toDTO(n), nil
}

func (s *Service) Delete(ctx context.Context, caller auth.Identity, animalID, noteID int32) error {
	if _, err := s.resolveReadOwner(ctx, caller, animalID); err != nil {
		return err
	}
	rows, err := s.q.DeleteNote(ctx, sqlc.DeleteNoteParams{ID: noteID, AnimalID: animalID, AuthorID: caller.UserID})
	if err != nil {
		return err
	}
	if rows == 0 {
		return httpx.ErrNotFound("note not found or not yours to delete")
	}
	return nil
}

// EmbedFirstPage returns the first page of notes for ?include=notes (§6.4).
func (s *Service) EmbedFirstPage(ctx context.Context, caller auth.Identity, animalID int32) ([]DTO, error) {
	rows, err := s.q.ListNotes(ctx, sqlc.ListNotesParams{
		AnimalID: animalID,
		OwnerID:  caller.UserID,
		Lim:      50,
	})
	if err != nil {
		return nil, err
	}
	out := make([]DTO, len(rows))
	for i, n := range rows {
		out[i] = toDTO(n)
	}
	return out, nil
}

func paginate(rows []sqlc.AnimalNote, limit int32) httpx.List[DTO] {
	out := httpx.List[DTO]{Data: make([]DTO, 0, len(rows))}
	for _, n := range rows {
		out.Data = append(out.Data, toDTO(n))
	}
	if int32(len(rows)) == limit && limit > 0 {
		last := rows[len(rows)-1]
		c := httpx.EncodeCursor(last.CreatedAt.Time, last.ID)
		out.NextCursor = &c
	}
	return out
}
