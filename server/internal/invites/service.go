// Package invites implements temporary, revocable doctor access (§4.3 rebuilt).
// A farm admin creates an invite (a QR secret + a doctor name); a doctor redeems
// the secret for a short-lived, farm-scoped session. Ending the invite revokes
// access instantly; the notes the doctor wrote remain as history.
package invites

import (
	"context"
	"errors"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgtype"
	"raai/internal/auth"
	"raai/internal/db/sqlc"
	"raai/internal/httpx"
)

type Service struct {
	q      *sqlc.Queries
	tokens *auth.TokenManager
}

func NewService(q *sqlc.Queries, tokens *auth.TokenManager) *Service {
	return &Service{q: q, tokens: tokens}
}

// DTO is an invite in the farm's history. Token is the QR secret (returned so the
// admin app can render/re-render the QR).
type DTO struct {
	ID          int32      `json:"id"`
	DoctorLabel string     `json:"doctorLabel"`
	Token       string     `json:"token,omitempty"`
	Status      string     `json:"status"`
	ExpiresAt   *time.Time `json:"expiresAt"`
	CreatedAt   time.Time  `json:"createdAt"`
	EndedAt     *time.Time `json:"endedAt"`
	NoteCount   int64      `json:"noteCount"`
}

// DoctorSession is what a doctor gets back from redeeming an invite.
type DoctorSession struct {
	AccessToken string    `json:"accessToken"`
	TokenType   string    `json:"tokenType"`
	ExpiresAt   time.Time `json:"expiresAt"`
	Farm        farmInfo  `json:"farm"`
	DoctorLabel string    `json:"doctorLabel"`
}

type farmInfo struct {
	ID   int32  `json:"id"`
	Name string `json:"name"`
}

func toDTO(i sqlc.DoctorInvite, noteCount int64) DTO {
	return DTO{
		ID:          i.ID,
		DoctorLabel: i.DoctorLabel,
		Token:       i.Token,
		Status:      i.Status,
		ExpiresAt:   httpx.TimePtr(i.ExpiresAt),
		CreatedAt:   httpx.TimeOf(i.CreatedAt),
		EndedAt:     httpx.TimePtr(i.EndedAt),
		NoteCount:   noteCount,
	}
}

// Create issues a new invite for the admin's farm.
func (s *Service) Create(ctx context.Context, farmID, adminID int32, doctorLabel string, expiresAt *time.Time) (DTO, error) {
	exp := pgtype.Timestamptz{}
	if expiresAt != nil {
		exp = pgtype.Timestamptz{Time: *expiresAt, Valid: true}
	}
	inv, err := s.q.CreateInvite(ctx, sqlc.CreateInviteParams{
		FarmID:      farmID,
		Token:       auth.NewRefreshToken(), // cryptographically random QR secret
		DoctorLabel: doctorLabel,
		ExpiresAt:   exp,
		CreatedBy:   &adminID,
	})
	if err != nil {
		return DTO{}, err
	}
	return toDTO(inv, 0), nil
}

// ListForFarm returns the farm's invite history with per-doctor note counts.
func (s *Service) ListForFarm(ctx context.Context, farmID int32) ([]DTO, error) {
	rows, err := s.q.ListInvitesByFarm(ctx, farmID)
	if err != nil {
		return nil, err
	}
	out := make([]DTO, 0, len(rows))
	for _, r := range rows {
		out = append(out, toDTO(sqlc.DoctorInvite{
			ID: r.ID, FarmID: r.FarmID, Token: r.Token, DoctorLabel: r.DoctorLabel,
			Status: r.Status, ExpiresAt: r.ExpiresAt, CreatedBy: r.CreatedBy,
			CreatedAt: r.CreatedAt, EndedAt: r.EndedAt, EndedBy: r.EndedBy,
		}, r.NoteCount))
	}
	return out, nil
}

// End revokes an active invite. The doctor's next request fails immediately.
func (s *Service) End(ctx context.Context, farmID, inviteID, endedBy int32) (DTO, error) {
	inv, err := s.q.EndInvite(ctx, sqlc.EndInviteParams{ID: inviteID, FarmID: farmID, EndedBy: &endedBy})
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return DTO{}, httpx.ErrNotFound("active invite not found")
		}
		return DTO{}, err
	}
	return toDTO(inv, 0), nil
}

// Redeem exchanges a QR secret for a short-lived doctor session. Doubles as the
// doctor's "refresh": the app re-redeems the stored secret when the token expires,
// and an ended/expired invite makes that fail (revocation).
func (s *Service) Redeem(ctx context.Context, token string) (DoctorSession, error) {
	inv, err := s.q.GetInviteByToken(ctx, token)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return DoctorSession{}, httpx.ErrUnauthorized("invalid visit code")
		}
		return DoctorSession{}, err
	}
	if inv.Status != "active" || (inv.ExpiresAt.Valid && inv.ExpiresAt.Time.Before(time.Now())) {
		return DoctorSession{}, httpx.ErrUnauthorized("this visit access has ended")
	}
	active, err := s.q.IsSubscriptionActive(ctx, inv.FarmID)
	if err != nil {
		return DoctorSession{}, err
	}
	if !active {
		return DoctorSession{}, httpx.ErrSubscriptionRequired("the farm's subscription is inactive")
	}
	farm, err := s.q.GetFarm(ctx, inv.FarmID)
	if err != nil {
		return DoctorSession{}, err
	}
	access, exp, err := s.tokens.IssueDoctor(inv.ID, inv.FarmID)
	if err != nil {
		return DoctorSession{}, err
	}
	return DoctorSession{
		AccessToken: access,
		TokenType:   "Bearer",
		ExpiresAt:   exp.UTC(),
		Farm:        farmInfo{ID: farm.ID, Name: farm.Name},
		DoctorLabel: inv.DoctorLabel,
	}, nil
}
