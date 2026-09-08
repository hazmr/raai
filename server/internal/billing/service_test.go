package billing

import (
	"testing"
	"time"

	"github.com/jackc/pgx/v5/pgtype"
	"raai/internal/db/sqlc"
)

func TestPlanMonths(t *testing.T) {
	cases := map[string]struct {
		want  int32
		valid bool
	}{
		"monthly": {1, true},
		"yearly":  {12, true},
		"weekly":  {0, false},
		"":        {0, false},
		"MONTHLY": {0, false}, // plans are matched exactly, not case-insensitively
	}
	for plan, tc := range cases {
		got, ok := PlanMonths(plan)
		if ok != tc.valid || got != tc.want {
			t.Errorf("PlanMonths(%q) = %d, %v; want %d, %v", plan, got, ok, tc.want, tc.valid)
		}
	}
}

func ts(t time.Time) pgtype.Timestamptz {
	return pgtype.Timestamptz{Time: t, Valid: true}
}

// Access is driven by current_period_end, not by the stored status column — a row
// left "active" with a past end date must still read as expired.
func TestDeriveStatus(t *testing.T) {
	future := time.Now().Add(24 * time.Hour)
	past := time.Now().Add(-24 * time.Hour)

	cases := map[string]struct {
		sub  sqlc.Subscription
		want string
	}{
		"live period":            {sqlc.Subscription{Status: "active", CurrentPeriodEnd: ts(future)}, "active"},
		"live period, stale row": {sqlc.Subscription{Status: "expired", CurrentPeriodEnd: ts(future)}, "active"},
		"lapsed period":          {sqlc.Subscription{Status: "active", CurrentPeriodEnd: ts(past)}, "expired"},
		"awaiting confirmation":  {sqlc.Subscription{Status: "pending"}, "pending"},
		"never paid":             {sqlc.Subscription{Status: "expired"}, "expired"},
	}
	for name, tc := range cases {
		if got := deriveStatus(tc.sub); got != tc.want {
			t.Errorf("%s: deriveStatus = %q, want %q", name, got, tc.want)
		}
	}
}

func TestPlansExposesPayeeAndPrices(t *testing.T) {
	svc := NewService(nil, Config{
		InstapayIPA:     "raai@instapay",
		DisplayName:     "Raai",
		PriceMonthlyEGP: 150,
		PriceYearlyEGP:  1500,
	})

	got := svc.Plans()
	if got.InstapayIPA != "raai@instapay" || got.DisplayName != "Raai" {
		t.Errorf("payee = %q/%q", got.InstapayIPA, got.DisplayName)
	}
	if got.Currency != "EGP" {
		t.Errorf("Currency = %q, want EGP", got.Currency)
	}
	if len(got.Plans) != 2 {
		t.Fatalf("len(Plans) = %d, want 2", len(got.Plans))
	}
	byID := map[string]int{}
	for _, p := range got.Plans {
		byID[p.ID] = p.AmountEGP
	}
	if byID["monthly"] != 150 || byID["yearly"] != 1500 {
		t.Errorf("prices = %v, want monthly 150 / yearly 1500", byID)
	}
}

func TestToPaymentDTOParsesNumericAmount(t *testing.T) {
	got := ToPaymentDTO(sqlc.Payment{
		ID:          9,
		Plan:        "yearly",
		AmountEgp:   "1500.00", // numeric(12,2) arrives as a string
		InstapayRef: "REF-1",
		Status:      "pending",
		CreatedAt:   ts(time.Now()),
	})
	if got.AmountEGP != 1500 {
		t.Errorf("AmountEGP = %v, want 1500", got.AmountEGP)
	}
	if got.ReviewedAt != nil {
		t.Errorf("ReviewedAt = %v, want nil for an unreviewed payment", got.ReviewedAt)
	}
}
