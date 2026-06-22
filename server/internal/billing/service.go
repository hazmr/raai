// Package billing implements the InstaPay subscription model (§7): user-facing
// plans/status/payment-submit, plus the paywall gate. Activation is driven solely
// by subscriptions.current_period_end, advanced by an admin confirm (see admin pkg).
package billing

import (
	"context"
	"errors"
	"strconv"
	"time"

	"github.com/jackc/pgx/v5"
	"raai/internal/db"
	"raai/internal/db/sqlc"
	"raai/internal/httpx"
)

// Config holds the InstaPay payee details and EGP pricing shown to users (§7.1).
type Config struct {
	InstapayIPA     string
	DisplayName     string
	PriceMonthlyEGP int
	PriceYearlyEGP  int
}

type Service struct {
	q   *sqlc.Queries
	cfg Config
}

func NewService(q *sqlc.Queries, cfg Config) *Service { return &Service{q: q, cfg: cfg} }

// Plan is one purchasable plan plus its EGP price (§7.3 /billing/plans).
type Plan struct {
	ID        string `json:"id"` // monthly | yearly
	AmountEGP int    `json:"amountEgp"`
}

// PlansResponse bundles the plans with the payee handle the user transfers to.
type PlansResponse struct {
	Plans       []Plan `json:"plans"`
	InstapayIPA string `json:"instapayIpa"`
	DisplayName string `json:"displayName"`
	Currency    string `json:"currency"`
}

func (s *Service) Plans() PlansResponse {
	return PlansResponse{
		Plans: []Plan{
			{ID: "monthly", AmountEGP: s.cfg.PriceMonthlyEGP},
			{ID: "yearly", AmountEGP: s.cfg.PriceYearlyEGP},
		},
		InstapayIPA: s.cfg.InstapayIPA,
		DisplayName: s.cfg.DisplayName,
		Currency:    "EGP",
	}
}

// StatusResponse is the current subscription state for the UI (§7.3).
type StatusResponse struct {
	Status           string     `json:"status"` // none | pending | active | expired
	Plan             *string    `json:"plan"`
	CurrentPeriodEnd *time.Time `json:"currentPeriodEnd"`
}

func (s *Service) Status(ctx context.Context, uid int32) (StatusResponse, error) {
	sub, err := s.q.GetSubscription(ctx, uid)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return StatusResponse{Status: "none"}, nil
		}
		return StatusResponse{}, err
	}
	resp := StatusResponse{
		Plan:             &sub.Plan,
		CurrentPeriodEnd: httpx.TimePtr(sub.CurrentPeriodEnd),
		Status:           deriveStatus(sub),
	}
	return resp, nil
}

func deriveStatus(sub sqlc.Subscription) string {
	if sub.CurrentPeriodEnd.Valid && sub.CurrentPeriodEnd.Time.After(time.Now()) {
		return "active"
	}
	if sub.Status == "pending" {
		return "pending"
	}
	return "expired"
}

// PaymentDTO is the §7.3 Payment shape.
type PaymentDTO struct {
	ID            int32      `json:"id"`
	Plan          string     `json:"plan"`
	AmountEGP     float64    `json:"amountEgp"`
	InstapayRef   string     `json:"instapayRef"`
	ScreenshotURL *string    `json:"screenshotUrl"`
	Status        string     `json:"status"`
	Note          *string    `json:"note"`
	ReviewedAt    *time.Time `json:"reviewedAt"`
	CreatedAt     time.Time  `json:"createdAt"`
}

// ToPaymentDTO is exported so the admin package can render the same shape.
func ToPaymentDTO(p sqlc.Payment) PaymentDTO {
	amount, _ := strconv.ParseFloat(p.AmountEgp, 64)
	return PaymentDTO{
		ID:            p.ID,
		Plan:          p.Plan,
		AmountEGP:     amount,
		InstapayRef:   p.InstapayRef,
		ScreenshotURL: p.ScreenshotUrl,
		Status:        p.Status,
		Note:          p.Note,
		ReviewedAt:    httpx.TimePtr(p.ReviewedAt),
		CreatedAt:     httpx.TimeOf(p.CreatedAt),
	}
}

// SubmitPayment records a claimed InstaPay transfer as a pending payment (§7.4).
// Dedupe is by instapay_ref: a re-submit by the same user returns the existing
// row (idempotent); a different user's reused ref is a 409.
func (s *Service) SubmitPayment(ctx context.Context, uid int32, plan, instapayRef string, amountEGP float64, screenshotURL *string) (PaymentDTO, error) {
	if _, ok := PlanMonths(plan); !ok {
		return PaymentDTO{}, httpx.ErrValidation("invalid plan", map[string]string{"plan": "must be 'monthly' or 'yearly'"})
	}
	if instapayRef == "" {
		return PaymentDTO{}, httpx.ErrValidation("instapayRef is required", map[string]string{"instapayRef": "is required"})
	}
	if amountEGP <= 0 {
		return PaymentDTO{}, httpx.ErrValidation("amountEgp must be positive", map[string]string{"amountEgp": "must be greater than 0"})
	}

	p, err := s.q.CreatePayment(ctx, sqlc.CreatePaymentParams{
		UserID:        uid,
		Plan:          plan,
		AmountEgp:     strconv.FormatFloat(amountEGP, 'f', 2, 64),
		InstapayRef:   instapayRef,
		ScreenshotUrl: screenshotURL,
	})
	if err != nil {
		if db.IsUniqueViolation(err) {
			existing, gerr := s.q.GetPaymentByRef(ctx, instapayRef)
			if gerr == nil && existing.UserID == uid {
				return ToPaymentDTO(existing), nil // idempotent re-submit
			}
			return PaymentDTO{}, httpx.ErrConflict("this InstaPay reference has already been submitted")
		}
		return PaymentDTO{}, err
	}

	// Surface "under review" without granting access (§7.4 step 3).
	if err := s.q.MarkPendingSubscription(ctx, sqlc.MarkPendingSubscriptionParams{UserID: uid, Plan: plan}); err != nil {
		return PaymentDTO{}, err
	}
	return ToPaymentDTO(p), nil
}

func (s *Service) ListUserPayments(ctx context.Context, uid int32, page httpx.Page) (httpx.List[PaymentDTO], error) {
	rows, err := s.q.ListPaymentsByUser(ctx, sqlc.ListPaymentsByUserParams{
		UserID:     uid,
		CursorTime: page.CursorTime(),
		CursorID:   page.CursorID(),
		Lim:        page.Limit,
	})
	if err != nil {
		return httpx.List[PaymentDTO]{}, err
	}
	out := httpx.List[PaymentDTO]{Data: make([]PaymentDTO, 0, len(rows))}
	for _, p := range rows {
		out.Data = append(out.Data, ToPaymentDTO(p))
	}
	if int32(len(rows)) == page.Limit && page.Limit > 0 {
		last := rows[len(rows)-1]
		c := httpx.EncodeCursor(last.CreatedAt.Time, last.ID)
		out.NextCursor = &c
	}
	return out, nil
}

// PlanMonths maps a plan to its length in months (+1 / +12, §7.4.5).
func PlanMonths(plan string) (int32, bool) {
	switch plan {
	case "monthly":
		return 1, true
	case "yearly":
		return 12, true
	default:
		return 0, false
	}
}
