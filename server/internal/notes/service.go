// Package notes implements the animal-notes sub-resource (§6.5). Notes are scoped
// to the caller's farm; authorship records whether a member or an invited doctor
// wrote them (§4.3), with the display name stamped at write time.
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
// authorKind (member|doctor) + authorLabel let the UI badge a doctor's note.
type DTO struct {
	ID         int32     `json:"id"`
	AnimalID   int32     `json:"animalId"`
	Body       string    `json:"body"`
	AuthorKind string    `json:"authorKind"`
	AuthorLabel string   `json:"authorLabel"`
	InviteID   *int32    `json:"inviteId"`
	CreatedAt  time.Time `json:"createdAt"`
	UpdatedAt  time.Time `json:"updatedAt"`
}

func toDTO(n sqlc.AnimalNote) DTO {
	return DTO{
		ID:          n.ID,
		AnimalID:    n.AnimalID,
		Body:        n.Notes,
		AuthorKind:  n.AuthorKind,
		AuthorLabel: n.AuthorLabel,
		InviteID:    n.AuthorInviteID,
		CreatedAt:   httpx.TimeOf(n.CreatedAt),
		UpdatedAt:   httpx.TimeOf(n.UpdatedAt),
	}
}

// requireAnimal confirms the animal belongs to the caller's farm (else 404).
func (s *Service) requireAnimal(ctx context.Context, caller auth.Identity, animalID int32) error {
	if _, err := s.q.GetAnimal(ctx, sqlc.GetAnimalParams{ID: animalID, FarmID: caller.FarmID}); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return httpx.ErrNotFound("animal not found")
		}
		return err
	}
	return nil
}

func (s *Service) List(ctx context.Context, caller auth.Identity, animalID int32, page httpx.Page) (httpx.List[DTO], error) {
	if err := s.requireAnimal(ctx, caller, animalID); err != nil {
		return httpx.List[DTO]{}, err
	}
	rows, err := s.q.ListNotes(ctx, sqlc.ListNotesParams{
		AnimalID:   animalID,
		FarmID:     caller.FarmID,
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
	n, err := s.q.GetNote(ctx, sqlc.GetNoteParams{ID: noteID, AnimalID: animalID, FarmID: caller.FarmID})
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return DTO{}, httpx.ErrNotFound("note not found")
		}
		return DTO{}, err
	}
	return toDTO(n), nil
}

// Create writes a note authored by the caller — a member (author_user_id) or a
// doctor (author_invite_id). The display name is stamped from the identity.
func (s *Service) Create(ctx context.Context, caller auth.Identity, animalID int32, body string) (DTO, error) {
	if err := s.requireAnimal(ctx, caller, animalID); err != nil {
		return DTO{}, err
	}
	params := sqlc.CreateNoteParams{
		AnimalID:    animalID,
		Notes:       body,
		AuthorLabel: caller.Label,
	}
	if caller.Kind == auth.KindDoctor {
		params.AuthorKind = "doctor"
		params.AuthorInviteID = &caller.InviteID
	} else {
		params.AuthorKind = "member"
		params.AuthorUserID = &caller.UserID
	}
	n, err := s.q.CreateNote(ctx, params)
	if err != nil {
		return DTO{}, err
	}
	return toDTO(n), nil
}

// Update edits a note; only its author may change it.
func (s *Service) Update(ctx context.Context, caller auth.Identity, animalID, noteID int32, body string) (DTO, error) {
	if err := s.requireAnimal(ctx, caller, animalID); err != nil {
		return DTO{}, err
	}
	var (
		n   sqlc.AnimalNote
		err error
	)
	if caller.Kind == auth.KindDoctor {
		n, err = s.q.UpdateNoteByInvite(ctx, sqlc.UpdateNoteByInviteParams{
			Notes: body, ID: noteID, AnimalID: animalID, AuthorInviteID: &caller.InviteID,
		})
	} else {
		n, err = s.q.UpdateNoteByUser(ctx, sqlc.UpdateNoteByUserParams{
			Notes: body, ID: noteID, AnimalID: animalID, AuthorUserID: &caller.UserID,
		})
	}
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return DTO{}, httpx.ErrNotFound("note not found or not yours to edit")
		}
		return DTO{}, err
	}
	return toDTO(n), nil
}

func (s *Service) Delete(ctx context.Context, caller auth.Identity, animalID, noteID int32) error {
	if err := s.requireAnimal(ctx, caller, animalID); err != nil {
		return err
	}
	var (
		rows int64
		err  error
	)
	if caller.Kind == auth.KindDoctor {
		rows, err = s.q.DeleteNoteByInvite(ctx, sqlc.DeleteNoteByInviteParams{ID: noteID, AnimalID: animalID, AuthorInviteID: &caller.InviteID})
	} else {
		rows, err = s.q.DeleteNoteByUser(ctx, sqlc.DeleteNoteByUserParams{ID: noteID, AnimalID: animalID, AuthorUserID: &caller.UserID})
	}
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
		FarmID:   caller.FarmID,
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
