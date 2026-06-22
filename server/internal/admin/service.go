// Package admin holds the single service layer behind both the JSON admin
// endpoints (§7.3) and the server-rendered dashboard (§8) — two transports, one
// logic. Every mutating action runs in one transaction and writes admin_audit.
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
// confirmed, extend the subscription from max(now, current_period_end), and audit.
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
			UserID:    p.UserID,
			Plan:      p.Plan,
			AddMonths: months,
		}); err != nil {
			return err
		}
		if err := q.CreateAudit(ctx, sqlc.CreateAuditParams{
			AdminID:    adminID,
			Action:     "confirm_payment",
			TargetUser: &p.UserID,
			PaymentID:  &p.ID,
			Detail:     strPtr(fmt.Sprintf("+%d month(s), plan=%s", months, p.Plan)),
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
			TargetUser: &p.UserID,
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

// Grant manually extends a user's subscription (off-band cash, comps) (§8.3).
func (s *Service) Grant(ctx context.Context, adminID, targetUser int32, plan string) error {
	months, ok := billing.PlanMonths(plan)
	if !ok {
		return httpx.ErrValidation("invalid plan", map[string]string{"plan": "must be 'monthly' or 'yearly'"})
	}
	return s.inTx(ctx, func(q *sqlc.Queries) error {
		if _, err := q.ExtendSubscription(ctx, sqlc.ExtendSubscriptionParams{
			UserID: targetUser, Plan: plan, AddMonths: months,
		}); err != nil {
			return err
		}
		return q.CreateAudit(ctx, sqlc.CreateAuditParams{
			AdminID:    adminID,
			Action:     "grant",
			TargetUser: &targetUser,
			Detail:     strPtr(fmt.Sprintf("+%d month(s) manual grant", months)),
		})
	})
}

// Revoke immediately ends a user's access (refund/abuse) (§8.3).
func (s *Service) Revoke(ctx context.Context, adminID, targetUser int32) error {
	return s.inTx(ctx, func(q *sqlc.Queries) error {
		if _, err := q.RevokeSubscription(ctx, targetUser); err != nil {
			return err
		}
		return q.CreateAudit(ctx, sqlc.CreateAuditParams{
			AdminID:    adminID,
			Action:     "revoke",
			TargetUser: &targetUser,
			Detail:     strPtr("manual revoke"),
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

func (s *Service) GetPayment(ctx context.Context, id int32) (sqlc.Payment, error) {
	return s.q.GetPayment(ctx, id)
}

func (s *Service) ListSubscribers(ctx context.Context, phone *string, limit, offset int32) ([]sqlc.ListSubscribersRow, error) {
	return s.q.ListSubscribers(ctx, sqlc.ListSubscribersParams{Phone: phone, Lim: limit, Off: offset})
}

func (s *Service) GetSubscriber(ctx context.Context, id int32) (sqlc.GetSubscriberDetailRow, error) {
	row, err := s.q.GetSubscriberDetail(ctx, id)
	if errors.Is(err, pgx.ErrNoRows) {
		return row, httpx.ErrNotFound("user not found")
	}
	return row, err
}

func (s *Service) ListUserPayments(ctx context.Context, uid int32) ([]sqlc.Payment, error) {
	return s.q.ListPaymentsByUser(ctx, sqlc.ListPaymentsByUserParams{UserID: uid, Lim: 20})
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
