// Package members lets a farm admin manage the farmers in their farm: list them,
// add one (by creating a phone+password login), and remove one. (§ farm refactor)
package members

import (
	"context"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"raai/internal/auth"
	"raai/internal/db"
	"raai/internal/db/sqlc"
	"raai/internal/httpx"
)

type Service struct {
	pool *pgxpool.Pool
	q    *sqlc.Queries
}

func NewService(pool *pgxpool.Pool, q *sqlc.Queries) *Service {
	return &Service{pool: pool, q: q}
}

type DTO struct {
	UserID      int32     `json:"userId"`
	PhoneNumber string    `json:"phoneNumber"`
	Role        string    `json:"role"`
	CreatedAt   time.Time `json:"createdAt"`
}

func (s *Service) List(ctx context.Context, farmID int32) ([]DTO, error) {
	rows, err := s.q.ListMembers(ctx, farmID)
	if err != nil {
		return nil, err
	}
	out := make([]DTO, 0, len(rows))
	for _, m := range rows {
		out = append(out, DTO{UserID: m.UserID, PhoneNumber: m.PhoneNumber, Role: m.Role, CreatedAt: httpx.TimeOf(m.CreatedAt)})
	}
	return out, nil
}

// Add creates a farmer login and attaches it to the farm. A taken phone (already a
// user, possibly in another farm) is a 409 — one farm per user.
func (s *Service) Add(ctx context.Context, farmID int32, phone, password string) (DTO, error) {
	hash, err := auth.HashPassword(password)
	if err != nil {
		return DTO{}, err
	}
	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return DTO{}, err
	}
	defer tx.Rollback(ctx)
	qtx := s.q.WithTx(tx)

	user, err := qtx.CreateUser(ctx, sqlc.CreateUserParams{PhoneNumber: phone, Password: hash})
	if err != nil {
		if db.IsUniqueViolation(err) {
			return DTO{}, httpx.ErrConflict("phone number is already registered")
		}
		return DTO{}, err
	}
	if _, err := qtx.AddMember(ctx, sqlc.AddMemberParams{FarmID: farmID, UserID: user.ID, Role: auth.RoleFarmer}); err != nil {
		return DTO{}, err
	}
	if err := tx.Commit(ctx); err != nil {
		return DTO{}, err
	}
	return DTO{UserID: user.ID, PhoneNumber: user.PhoneNumber, Role: auth.RoleFarmer, CreatedAt: httpx.TimeOf(user.CreatedAt)}, nil
}

// Remove detaches a farmer (the query refuses to remove an admin).
func (s *Service) Remove(ctx context.Context, farmID, userID int32) error {
	rows, err := s.q.RemoveMember(ctx, sqlc.RemoveMemberParams{FarmID: farmID, UserID: userID})
	if err != nil {
		return err
	}
	if rows == 0 {
		return httpx.ErrNotFound("member not found (or is an admin)")
	}
	return nil
}
