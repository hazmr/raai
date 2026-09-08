package server_test

import (
	"fmt"
	"net/http"
	"testing"
	"time"

	"raai/internal/testutil"
)

type paymentDTO struct {
	ID          int32   `json:"id"`
	Plan        string  `json:"plan"`
	AmountEGP   float64 `json:"amountEgp"`
	InstapayRef string  `json:"instapayRef"`
	Status      string  `json:"status"`
	Note        *string `json:"note"`
}

type statusDTO struct {
	Status           string     `json:"status"`
	Plan             *string    `json:"plan"`
	CurrentPeriodEnd *time.Time `json:"currentPeriodEnd"`
}

func submitPayment(t *testing.T, env *testutil.Env, token, plan, ref string, amount float64) paymentDTO {
	t.Helper()
	var p paymentDTO
	env.Do(http.MethodPost, "/api/v1/billing/payments", token, map[string]any{
		"plan":        plan,
		"instapayRef": ref,
		"amountEgp":   amount,
	}).ExpectStatus(http.StatusCreated).JSON(&p)
	return p
}

func billingStatus(t *testing.T, env *testutil.Env, token string) statusDTO {
	t.Helper()
	var s statusDTO
	env.Do(http.MethodGet, "/api/v1/billing/status", token, nil).
		ExpectStatus(http.StatusOK).JSON(&s)
	return s
}

func TestPlansExposePayeeAndPrices(t *testing.T) {
	env := testutil.New(t)
	acct := env.Register("01200000001", "secret123", "Farm")

	var plans struct {
		Plans []struct {
			ID        string `json:"id"`
			AmountEGP int    `json:"amountEgp"`
		} `json:"plans"`
		InstapayIPA string `json:"instapayIpa"`
		Currency    string `json:"currency"`
	}
	env.Do(http.MethodGet, "/api/v1/billing/plans", acct.Access, nil).
		ExpectStatus(http.StatusOK).JSON(&plans)

	if plans.InstapayIPA == "" {
		t.Error("instapayIpa is empty — the user would have nowhere to transfer to")
	}
	if plans.Currency != "EGP" {
		t.Errorf("currency = %q, want EGP", plans.Currency)
	}
	if len(plans.Plans) != 2 {
		t.Fatalf("len(plans) = %d, want 2", len(plans.Plans))
	}
}

func TestStatusIsNoneBeforeAnyPayment(t *testing.T) {
	env := testutil.New(t)
	acct := env.Register("01200000002", "secret123", "Farm")

	if got := billingStatus(t, env, acct.Access); got.Status != "none" {
		t.Errorf("status = %q, want none", got.Status)
	}
}

// Submitting a reference must never grant access on its own — an admin confirms.
func TestSubmitPaymentIsPendingAndGrantsNothing(t *testing.T) {
	env := testutil.New(t)
	acct := env.Register("01200000003", "secret123", "Farm")

	p := submitPayment(t, env, acct.Access, "monthly", "INSTA-REF-1", 150)
	if p.Status != "pending" {
		t.Errorf("payment status = %q, want pending", p.Status)
	}
	if p.AmountEGP != 150 {
		t.Errorf("amountEgp = %v, want 150", p.AmountEGP)
	}

	if got := billingStatus(t, env, acct.Access); got.Status != "pending" {
		t.Errorf("subscription status = %q, want pending", got.Status)
	}
	env.Do(http.MethodGet, "/api/v1/animals", acct.Access, nil).
		ExpectStatus(http.StatusPaymentRequired)
}

// A farmer on a bad connection taps "send" twice; that must not create two claims.
func TestResubmittingSameReferenceIsIdempotent(t *testing.T) {
	env := testutil.New(t)
	acct := env.Register("01200000004", "secret123", "Farm")

	first := submitPayment(t, env, acct.Access, "monthly", "INSTA-REF-2", 150)
	second := submitPayment(t, env, acct.Access, "monthly", "INSTA-REF-2", 150)
	if first.ID != second.ID {
		t.Errorf("payment ids %d and %d differ — the re-submit created a second claim", first.ID, second.ID)
	}

	var list struct {
		Data []paymentDTO `json:"data"`
	}
	env.Do(http.MethodGet, "/api/v1/billing/payments", acct.Access, nil).
		ExpectStatus(http.StatusOK).JSON(&list)
	if len(list.Data) != 1 {
		t.Errorf("farm has %d payments, want 1", len(list.Data))
	}
}

// Someone else's transfer reference must not be claimable.
func TestReferenceCannotBeClaimedByAnotherFarm(t *testing.T) {
	env := testutil.New(t)
	one := env.Register("01200000005", "secret123", "Farm One")
	two := env.Register("01200000006", "secret123", "Farm Two")

	submitPayment(t, env, one.Access, "monthly", "INSTA-SHARED", 150)

	resp := env.Do(http.MethodPost, "/api/v1/billing/payments", two.Access, map[string]any{
		"plan":        "monthly",
		"instapayRef": "INSTA-SHARED",
		"amountEgp":   150,
	}).ExpectStatus(http.StatusConflict)
	if code := resp.ErrorCode(); code != "conflict" {
		t.Errorf("code = %q, want conflict", code)
	}
}

func TestSubmitPaymentValidatesInput(t *testing.T) {
	env := testutil.New(t)
	acct := env.Register("01200000007", "secret123", "Farm")

	cases := map[string]map[string]any{
		"unknown plan":    {"plan": "weekly", "instapayRef": "R1", "amountEgp": 150},
		"missing ref":     {"plan": "monthly", "instapayRef": "   ", "amountEgp": 150},
		"zero amount":     {"plan": "monthly", "instapayRef": "R2", "amountEgp": 0},
		"negative amount": {"plan": "monthly", "instapayRef": "R3", "amountEgp": -50},
	}
	for name, body := range cases {
		resp := env.Do(http.MethodPost, "/api/v1/billing/payments", acct.Access, body).
			ExpectStatus(http.StatusUnprocessableEntity)
		if code := resp.ErrorCode(); code != "validation_error" {
			t.Errorf("%s: code = %q, want validation_error", name, code)
		}
	}
}

// Only the farm admin pays; a plain member must not submit or read payments.
func TestOnlyFarmAdminManagesBilling(t *testing.T) {
	env := testutil.New(t)
	admin := env.Register("01200000008", "secret123", "Farm")
	env.Activate(admin.FarmID)

	env.Do(http.MethodPost, "/api/v1/farm/members", admin.Access, map[string]string{
		"phoneNumber": "01200000009",
		"password":    "secret123",
	}).ExpectStatus(http.StatusCreated)

	var tokens struct {
		AccessToken string `json:"accessToken"`
	}
	env.Do(http.MethodPost, "/api/v1/auth/login", "", map[string]string{
		"phoneNumber": "01200000009",
		"password":    "secret123",
	}).ExpectStatus(http.StatusOK).JSON(&tokens)

	env.Do(http.MethodPost, "/api/v1/billing/payments", tokens.AccessToken, map[string]any{
		"plan": "monthly", "instapayRef": "MEMBER-REF", "amountEgp": 150,
	}).ExpectStatus(http.StatusForbidden)

	env.Do(http.MethodGet, "/api/v1/billing/payments", tokens.AccessToken, nil).
		ExpectStatus(http.StatusForbidden)

	// Reading plans/status is fine — it is the write side that is admin-only.
	env.Do(http.MethodGet, "/api/v1/billing/plans", tokens.AccessToken, nil).
		ExpectStatus(http.StatusOK)
}

func TestPaymentsAreScopedToTheFarm(t *testing.T) {
	env := testutil.New(t)
	one := env.Register("01200000010", "secret123", "Farm One")
	two := env.Register("01200000011", "secret123", "Farm Two")

	submitPayment(t, env, one.Access, "monthly", "REF-ONE", 150)

	var list struct {
		Data []paymentDTO `json:"data"`
	}
	env.Do(http.MethodGet, "/api/v1/billing/payments", two.Access, nil).
		ExpectStatus(http.StatusOK).JSON(&list)
	if len(list.Data) != 0 {
		t.Errorf("farm two sees %d payments, want 0", len(list.Data))
	}
}

func TestSubmitPaymentRequiresAuthentication(t *testing.T) {
	env := testutil.New(t)

	env.Do(http.MethodPost, "/api/v1/billing/payments", "", map[string]any{
		"plan": "monthly", "instapayRef": "ANON", "amountEgp": 150,
	}).ExpectStatus(http.StatusUnauthorized)
}

func TestBillingStatusReportsPlanAndPeriodEnd(t *testing.T) {
	env := testutil.New(t)
	acct := env.Register("01200000012", "secret123", "Farm")
	env.Activate(acct.FarmID)

	got := billingStatus(t, env, acct.Access)
	if got.Status != "active" {
		t.Fatalf("status = %q, want active", got.Status)
	}
	if got.Plan == nil || *got.Plan != "monthly" {
		t.Errorf("plan = %v, want monthly", got.Plan)
	}
	if got.CurrentPeriodEnd == nil || !got.CurrentPeriodEnd.After(time.Now()) {
		t.Errorf("currentPeriodEnd = %v, want a future time", got.CurrentPeriodEnd)
	}
}

func TestPaymentHistoryListsNewestFirst(t *testing.T) {
	env := testutil.New(t)
	acct := env.Register("01200000013", "secret123", "Farm")

	for i := range 3 {
		submitPayment(t, env, acct.Access, "monthly", fmt.Sprintf("HIST-%d", i), 150)
	}

	var list struct {
		Data []paymentDTO `json:"data"`
	}
	env.Do(http.MethodGet, "/api/v1/billing/payments", acct.Access, nil).
		ExpectStatus(http.StatusOK).JSON(&list)
	if len(list.Data) != 3 {
		t.Fatalf("history has %d rows, want 3", len(list.Data))
	}
	if list.Data[0].InstapayRef != "HIST-2" {
		t.Errorf("first row = %q, want the newest (HIST-2)", list.Data[0].InstapayRef)
	}
}
