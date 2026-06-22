// Package visits implements the visit lifecycle and vet-access model (§4.3, §6.8).
// A visit is the time-boxed grant: the farmer opens it to authorize a vet, and
// closing it ends the vet's write access.
package visits

import (
	"context"
	"errors"
	"time"

	"github.com/jackc/pgx/v5"
	"raai/internal/animals"
	"raai/internal/auth"
	"raai/internal/db"
	"raai/internal/db/sqlc"
	"raai/internal/httpx"
)

type Service struct {
	q       *sqlc.Queries
	animals *animals.Service
}

func NewService(q *sqlc.Queries, a *animals.Service) *Service {
	return &Service{q: q, animals: a}
}

// DTO is the §6.8 Visit shape.
type DTO struct {
	ID            int32      `json:"id"`
	FarmerID      int32      `json:"farmerId"`
	VetID         *int32     `json:"vetId"`
	LocationType  string     `json:"locationType"`
	LocationLabel *string    `json:"locationLabel"`
	Status        string     `json:"status"`
	OpenedAt      time.Time  `json:"openedAt"`
	ClosedAt      *time.Time `json:"closedAt"`
}

func toDTO(v sqlc.Visit) DTO {
	return DTO{
		ID:            v.ID,
		FarmerID:      v.FarmerID,
		VetID:         v.VetID,
		LocationType:  v.LocationType,
		LocationLabel: v.LocationLabel,
		Status:        v.Status,
		OpenedAt:      httpx.TimeOf(v.OpenedAt),
		ClosedAt:      httpx.TimePtr(v.ClosedAt),
	}
}

// Open creates a visit. If vetPhone is given, it must resolve to an existing vet
// account (§6.8: never silently promote); otherwise the visit is the farmer's own
// session (vetId null).
func (s *Service) Open(ctx context.Context, farmerID int32, vetPhone *string, locationType string, locationLabel *string) (DTO, error) {
	if locationType != "clinic" && locationType != "farm" {
		return DTO{}, httpx.ErrValidation("invalid location type", map[string]string{"locationType": "must be 'clinic' or 'farm'"})
	}
	var vetID *int32
	if vetPhone != nil && *vetPhone != "" {
		vet, err := s.q.GetUserByPhone(ctx, *vetPhone)
		if err != nil {
			if errors.Is(err, pgx.ErrNoRows) {
				return DTO{}, httpx.ErrNotFound("no vet account with that phone — ask them to register as a vet first")
			}
			return DTO{}, err
		}
		if vet.Role != auth.RoleVet {
			return DTO{}, httpx.ErrValidation("that account is not a vet", map[string]string{"vetPhone": "must belong to a vet"})
		}
		vetID = &vet.ID
	}
	v, err := s.q.CreateVisit(ctx, sqlc.CreateVisitParams{
		FarmerID:      farmerID,
		VetID:         vetID,
		LocationType:  locationType,
		LocationLabel: locationLabel,
	})
	if err != nil {
		if db.IsUniqueViolation(err) {
			return DTO{}, httpx.ErrConflict("an open visit with this vet already exists")
		}
		return DTO{}, err
	}
	return toDTO(v), nil
}

func (s *Service) ListForFarmer(ctx context.Context, farmerID int32, page httpx.Page) (httpx.List[DTO], error) {
	rows, err := s.q.ListVisitsByFarmer(ctx, sqlc.ListVisitsByFarmerParams{
		FarmerID:   farmerID,
		CursorTime: page.CursorTime(),
		CursorID:   page.CursorID(),
		Lim:        page.Limit,
	})
	if err != nil {
		return httpx.List[DTO]{}, err
	}
	return paginate(rows, page.Limit), nil
}

func (s *Service) ListForVet(ctx context.Context, vetID int32, status *string, page httpx.Page) (httpx.List[DTO], error) {
	rows, err := s.q.ListVisitsByVet(ctx, sqlc.ListVisitsByVetParams{
		VetID:      &vetID,
		Status:     status,
		CursorTime: page.CursorTime(),
		CursorID:   page.CursorID(),
		Lim:        page.Limit,
	})
	if err != nil {
		return httpx.List[DTO]{}, err
	}
	return paginate(rows, page.Limit), nil
}

func (s *Service) Close(ctx context.Context, farmerID, visitID int32) (DTO, error) {
	v, err := s.q.CloseVisit(ctx, sqlc.CloseVisitParams{ID: visitID, FarmerID: farmerID})
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return DTO{}, httpx.ErrNotFound("open visit not found")
		}
		return DTO{}, err
	}
	return toDTO(v), nil
}

// AnimalsForVisit returns the farmer's herd for a vet on an open visit (§6.8),
// gated by the farmer's subscription.
func (s *Service) AnimalsForVisit(ctx context.Context, vetID, visitID int32, page httpx.Page) (httpx.List[animals.DTO], error) {
	visit, err := s.q.GetOpenVisitForVet(ctx, sqlc.GetOpenVisitForVetParams{ID: visitID, VetID: &vetID})
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return httpx.List[animals.DTO]{}, httpx.ErrForbidden("not assigned to this visit, or it is closed")
		}
		return httpx.List[animals.DTO]{}, err
	}
	active, err := s.q.IsSubscriptionActive(ctx, visit.FarmerID)
	if err != nil {
		return httpx.List[animals.DTO]{}, err
	}
	if !active {
		return httpx.List[animals.DTO]{}, httpx.ErrSubscriptionRequired("the herd owner's subscription is inactive")
	}
	return s.animals.ListForOwner(ctx, visit.FarmerID, page)
}

func paginate(rows []sqlc.Visit, limit int32) httpx.List[DTO] {
	out := httpx.List[DTO]{Data: make([]DTO, 0, len(rows))}
	for _, v := range rows {
		out.Data = append(out.Data, toDTO(v))
	}
	if int32(len(rows)) == limit && limit > 0 {
		last := rows[len(rows)-1]
		c := httpx.EncodeCursor(last.OpenedAt.Time, last.ID)
		out.NextCursor = &c
	}
	return out
}
