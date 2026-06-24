// Package admin holds the single service layer behind both the JSON admin
// endpoints (§7.3) and the server-rendered dashboard (§8) — two transports, one
// logic. Subscriptions are per-farm. Every mutating action runs in one
// transaction and writes admin_audit.
package admin

import (
	"context"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"raai/internal/billing"
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

// ConfirmPayment performs the §7.4.5 one-transaction confirm: mark the payment
// confirmed, extend the FARM's subscription from max(now, current_period_end),
// and audit.
func (s *Service) ConfirmPayment(ctx context.Context, adminID, paymentID int32) (billing.PaymentDTO, error) {
	var dto billing.PaymentDTO
	err := s.inTx(ctx, func(q *sqlc.Queries) error {
		p, err := q.ReviewPayment(ctx, sqlc.ReviewPaymentParams{
			Status:     "confirmed",
			ReviewedBy: &adminID,
			ID:         paymentID,
		})
		if err != nil {
			if errors.Is(err, pgx.ErrNoRows) {
				return httpx.ErrNotFound("no pending payment with that id")
			}
			return err
		}
		months, ok := billing.PlanMonths(p.Plan)
		if !ok {
			return httpx.ErrValidation("payment has an invalid plan", nil)
		}
		if _, err := q.ExtendSubscription(ctx, sqlc.ExtendSubscriptionParams{
			FarmID:    p.FarmID,
			Plan:      p.Plan,
			AddMonths: months,
		}); err != nil {
			return err
		}
		if err := q.CreateAudit(ctx, sqlc.CreateAuditParams{
			AdminID:    adminID,
			Action:     "confirm_payment",
			TargetUser: p.CreatedBy,
			PaymentID:  &p.ID,
			Detail:     strPtr(fmt.Sprintf("farm=%d +%d month(s), plan=%s", p.FarmID, months, p.Plan)),
		}); err != nil {
			return err
		}
		dto = billing.ToPaymentDTO(p)
		return nil
	})
	return dto, err
}

// RejectPayment marks a pending payment rejected with a note and audits it (§8.3).
func (s *Service) RejectPayment(ctx context.Context, adminID, paymentID int32, note string) (billing.PaymentDTO, error) {
	var dto billing.PaymentDTO
	err := s.inTx(ctx, func(q *sqlc.Queries) error {
		var notePtr *string
		if note != "" {
			notePtr = &note
		}
		p, err := q.ReviewPayment(ctx, sqlc.ReviewPaymentParams{
			Status:     "rejected",
			ReviewedBy: &adminID,
			Note:       notePtr,
			ID:         paymentID,
		})
		if err != nil {
			if errors.Is(err, pgx.ErrNoRows) {
				return httpx.ErrNotFound("no pending payment with that id")
			}
			return err
		}
		if err := q.CreateAudit(ctx, sqlc.CreateAuditParams{
			AdminID:    adminID,
			Action:     "reject_payment",
			TargetUser: p.CreatedBy,
			PaymentID:  &p.ID,
			Detail:     notePtr,
		}); err != nil {
			return err
		}
		dto = billing.ToPaymentDTO(p)
		return nil
	})
	return dto, err
}

// Grant manually extends a farm's subscription (off-band cash, comps) (§8.3).
func (s *Service) Grant(ctx context.Context, adminID, targetFarm int32, plan string) error {
	months, ok := billing.PlanMonths(plan)
	if !ok {
		return httpx.ErrValidation("invalid plan", map[string]string{"plan": "must be 'monthly' or 'yearly'"})
	}
	return s.inTx(ctx, func(q *sqlc.Queries) error {
		if _, err := q.ExtendSubscription(ctx, sqlc.ExtendSubscriptionParams{
			FarmID: targetFarm, Plan: plan, AddMonths: months,
		}); err != nil {
			return err
		}
		return q.CreateAudit(ctx, sqlc.CreateAuditParams{
			AdminID: adminID,
			Action:  "grant",
			Detail:  strPtr(fmt.Sprintf("farm=%d +%d month(s) manual grant", targetFarm, months)),
		})
	})
}

// Revoke immediately ends a farm's access (refund/abuse) (§8.3).
func (s *Service) Revoke(ctx context.Context, adminID, targetFarm int32) error {
	return s.inTx(ctx, func(q *sqlc.Queries) error {
		if _, err := q.RevokeSubscription(ctx, targetFarm); err != nil {
			return err
		}
		return q.CreateAudit(ctx, sqlc.CreateAuditParams{
			AdminID: adminID,
			Action:  "revoke",
			Detail:  strPtr(fmt.Sprintf("farm=%d manual revoke", targetFarm)),
		})
	})
}

// --- read paths (shared by JSON + dashboard) ---

func (s *Service) Stats(ctx context.Context) (sqlc.AdminStatsRow, error) {
	return s.q.AdminStats(ctx)
}

func (s *Service) ListPayments(ctx context.Context, status *string, page httpx.Page) (httpx.List[billing.PaymentDTO], error) {
	rows, err := s.q.ListPayments(ctx, sqlc.ListPaymentsParams{
		Status:     status,
		CursorTime: page.CursorTime(),
		CursorID:   page.CursorID(),
		Lim:        page.Limit,
	})
	if err != nil {
		return httpx.List[billing.PaymentDTO]{}, err
	}
	out := httpx.List[billing.PaymentDTO]{Data: make([]billing.PaymentDTO, 0, len(rows))}
	for _, p := range rows {
		out.Data = append(out.Data, billing.ToPaymentDTO(p))
	}
	if int32(len(rows)) == page.Limit && page.Limit > 0 {
		last := rows[len(rows)-1]
		c := httpx.EncodeCursor(last.CreatedAt.Time, last.ID)
		out.NextCursor = &c
	}
	return out, nil
}

func (s *Service) ListPaymentsDetailed(ctx context.Context, status *string, limit int32) ([]sqlc.ListPaymentsDetailedRow, error) {
	return s.q.ListPaymentsDetailed(ctx, sqlc.ListPaymentsDetailedParams{Status: status, Lim: limit})
}

func (s *Service) GetPayment(ctx context.Context, id int32) (sqlc.Payment, error) {
	return s.q.GetPayment(ctx, id)
}

func (s *Service) ListFarms(ctx context.Context, q *string, limit, offset int32) ([]sqlc.ListFarmsRow, error) {
	return s.q.ListFarms(ctx, sqlc.ListFarmsParams{Q: q, Lim: limit, Off: offset})
}

func (s *Service) GetFarm(ctx context.Context, id int32) (sqlc.GetFarmDetailRow, error) {
	row, err := s.q.GetFarmDetail(ctx, id)
	if errors.Is(err, pgx.ErrNoRows) {
		return row, httpx.ErrNotFound("farm not found")
	}
	return row, err
}

func (s *Service) ListFarmMembers(ctx context.Context, farmID int32) ([]sqlc.ListMembersRow, error) {
	return s.q.ListMembers(ctx, farmID)
}

func (s *Service) ListFarmInvites(ctx context.Context, farmID int32) ([]sqlc.ListInvitesByFarmRow, error) {
	return s.q.ListInvitesByFarm(ctx, farmID)
}

func (s *Service) ListFarmPayments(ctx context.Context, farmID int32) ([]sqlc.Payment, error) {
	return s.q.ListPaymentsByFarm(ctx, sqlc.ListPaymentsByFarmParams{FarmID: farmID, Lim: 20})
}

func (s *Service) inTx(ctx context.Context, fn func(*sqlc.Queries) error) error {
	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx)
	if err := fn(s.q.WithTx(tx)); err != nil {
		return err
	}
	return tx.Commit(ctx)
}

func strPtr(s string) *string { return &s }
