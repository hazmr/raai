package server_test

import (
	"context"
	"fmt"
	"net/http"
	"testing"
	"time"

	"raai/internal/testutil"
)

// superAdmin registers an account and promotes it to app super-admin.
func superAdmin(t *testing.T, env *testutil.Env, phone string) *testutil.Account {
	t.Helper()
	acct := env.Register(phone, "secret123", "Ops")
	env.MakeSuperAdmin(acct.UserID)
	return acct
}

// periodEnd reads a farm's subscription end straight from the database.
func periodEnd(t *testing.T, env *testutil.Env, farmID int32) time.Time {
	t.Helper()
	var end *time.Time
	err := env.Pool.QueryRow(context.Background(),
		`SELECT current_period_end FROM subscriptions WHERE farm_id = $1`, farmID).Scan(&end)
	if err != nil {
		t.Fatalf("read subscription for farm %d: %v", farmID, err)
	}
	if end == nil {
		t.Fatalf("farm %d has no current_period_end", farmID)
	}
	return *end
}

// The core money path: a confirmed InstaPay reference opens the paywall.
func TestConfirmPaymentActivatesTheFarm(t *testing.T) {
	env := testutil.New(t)
	farmer := env.Register("01300000001", "secret123", "Farm")
	ops := superAdmin(t, env, "01300000002")

	payment := submitPayment(t, env, farmer.Access, "monthly", "CONF-1", 150)
	env.Do(http.MethodGet, "/api/v1/animals", farmer.Access, nil).
		ExpectStatus(http.StatusPaymentRequired)

	var confirmed paymentDTO
	env.Do(http.MethodPost, fmt.Sprintf("/api/v1/admin/payments/%d/confirm", payment.ID), ops.Access, nil).
		ExpectStatus(http.StatusOK).JSON(&confirmed)
	if confirmed.Status != "confirmed" {
		t.Errorf("payment status = %q, want confirmed", confirmed.Status)
	}

	env.Do(http.MethodGet, "/api/v1/animals", farmer.Access, nil).ExpectStatus(http.StatusOK)

	if got := billingStatus(t, env, farmer.Access); got.Status != "active" {
		t.Errorf("subscription status = %q, want active", got.Status)
	}

	// A monthly plan buys roughly one month.
	end := periodEnd(t, env, farmer.FarmID)
	wantMin, wantMax := time.Now().AddDate(0, 0, 27), time.Now().AddDate(0, 0, 32)
	if end.Before(wantMin) || end.After(wantMax) {
		t.Errorf("current_period_end = %v, want ~1 month out", end)
	}
}

func TestConfirmYearlyPaymentBuysTwelveMonths(t *testing.T) {
	env := testutil.New(t)
	farmer := env.Register("01300000003", "secret123", "Farm")
	ops := superAdmin(t, env, "01300000004")

	payment := submitPayment(t, env, farmer.Access, "yearly", "CONF-YEAR", 1500)
	env.Do(http.MethodPost, fmt.Sprintf("/api/v1/admin/payments/%d/confirm", payment.ID), ops.Access, nil).
		ExpectStatus(http.StatusOK)

	end := periodEnd(t, env, farmer.FarmID)
	wantMin, wantMax := time.Now().AddDate(0, 11, 25), time.Now().AddDate(1, 0, 5)
	if end.Before(wantMin) || end.After(wantMax) {
		t.Errorf("current_period_end = %v, want ~12 months out", end)
	}
}

// Renewing early must stack on the remaining time, not throw it away.
func TestConfirmingWhileActiveExtendsFromTheExistingPeriod(t *testing.T) {
	env := testutil.New(t)
	farmer := env.Register("01300000005", "secret123", "Farm")
	ops := superAdmin(t, env, "01300000006")

	env.Activate(farmer.FarmID) // ~30 days remaining
	before := periodEnd(t, env, farmer.FarmID)

	payment := submitPayment(t, env, farmer.Access, "monthly", "CONF-RENEW", 150)
	env.Do(http.MethodPost, fmt.Sprintf("/api/v1/admin/payments/%d/confirm", payment.ID), ops.Access, nil).
		ExpectStatus(http.StatusOK)

	after := periodEnd(t, env, farmer.FarmID)
	if !after.After(before.AddDate(0, 0, 25)) {
		t.Errorf("period end went %v → %v; an early renewal should add ~a month to the remaining time", before, after)
	}
}

// Double-tapping confirm must not buy the farmer two months.
func TestConfirmingTwiceIsRejected(t *testing.T) {
	env := testutil.New(t)
	farmer := env.Register("01300000007", "secret123", "Farm")
	ops := superAdmin(t, env, "01300000008")

	payment := submitPayment(t, env, farmer.Access, "monthly", "CONF-TWICE", 150)
	path := fmt.Sprintf("/api/v1/admin/payments/%d/confirm", payment.ID)

	env.Do(http.MethodPost, path, ops.Access, nil).ExpectStatus(http.StatusOK)
	first := periodEnd(t, env, farmer.FarmID)

	resp := env.Do(http.MethodPost, path, ops.Access, nil).ExpectStatus(http.StatusNotFound)
	if code := resp.ErrorCode(); code != "not_found" {
		t.Errorf("code = %q, want not_found", code)
	}
	if second := periodEnd(t, env, farmer.FarmID); !second.Equal(first) {
		t.Errorf("period end moved %v → %v on a repeated confirm", first, second)
	}
}

func TestRejectPaymentLeavesFarmLocked(t *testing.T) {
	env := testutil.New(t)
	farmer := env.Register("01300000009", "secret123", "Farm")
	ops := superAdmin(t, env, "01300000010")

	payment := submitPayment(t, env, farmer.Access, "monthly", "REJ-1", 150)

	var rejected paymentDTO
	env.Do(http.MethodPost, fmt.Sprintf("/api/v1/admin/payments/%d/reject", payment.ID), ops.Access,
		map[string]string{"note": "no transfer found"}).
		ExpectStatus(http.StatusOK).JSON(&rejected)

	if rejected.Status != "rejected" {
		t.Errorf("status = %q, want rejected", rejected.Status)
	}
	if rejected.Note == nil || *rejected.Note != "no transfer found" {
		t.Errorf("note = %v, want the reviewer's note", rejected.Note)
	}
	env.Do(http.MethodGet, "/api/v1/animals", farmer.Access, nil).
		ExpectStatus(http.StatusPaymentRequired)
}

func TestRejectedPaymentCannotLaterBeConfirmed(t *testing.T) {
	env := testutil.New(t)
	farmer := env.Register("01300000011", "secret123", "Farm")
	ops := superAdmin(t, env, "01300000012")

	payment := submitPayment(t, env, farmer.Access, "monthly", "REJ-2", 150)
	env.Do(http.MethodPost, fmt.Sprintf("/api/v1/admin/payments/%d/reject", payment.ID), ops.Access,
		map[string]string{"note": "duplicate"}).ExpectStatus(http.StatusOK)

	env.Do(http.MethodPost, fmt.Sprintf("/api/v1/admin/payments/%d/confirm", payment.ID), ops.Access, nil).
		ExpectStatus(http.StatusNotFound)
	env.Do(http.MethodGet, "/api/v1/animals", farmer.Access, nil).
		ExpectStatus(http.StatusPaymentRequired)
}

// Every confirm/reject leaves an audit trail naming the reviewing admin.
func TestReviewsAreAudited(t *testing.T) {
	env := testutil.New(t)
	farmer := env.Register("01300000013", "secret123", "Farm")
	ops := superAdmin(t, env, "01300000014")

	confirmMe := submitPayment(t, env, farmer.Access, "monthly", "AUDIT-1", 150)
	env.Do(http.MethodPost, fmt.Sprintf("/api/v1/admin/payments/%d/confirm", confirmMe.ID), ops.Access, nil).
		ExpectStatus(http.StatusOK)

	rejectMe := submitPayment(t, env, farmer.Access, "monthly", "AUDIT-2", 150)
	env.Do(http.MethodPost, fmt.Sprintf("/api/v1/admin/payments/%d/reject", rejectMe.ID), ops.Access,
		map[string]string{"note": "wrong amount"}).ExpectStatus(http.StatusOK)

	rows, err := env.Pool.Query(context.Background(),
		`SELECT action, admin_id, payment_id FROM admin_audit ORDER BY id`)
	if err != nil {
		t.Fatalf("read audit: %v", err)
	}
	defer rows.Close()

	var actions []string
	for rows.Next() {
		var action string
		var adminID int32
		var paymentID *int32
		if err := rows.Scan(&action, &adminID, &paymentID); err != nil {
			t.Fatalf("scan audit row: %v", err)
		}
		if adminID != ops.UserID {
			t.Errorf("audit admin_id = %d, want %d", adminID, ops.UserID)
		}
		if paymentID == nil {
			t.Errorf("audit row for %q has no payment_id", action)
		}
		actions = append(actions, action)
	}
	if len(actions) != 2 || actions[0] != "confirm_payment" || actions[1] != "reject_payment" {
		t.Errorf("audit actions = %v, want [confirm_payment reject_payment]", actions)
	}
}

// Being a farm admin must not grant access to other people's payments.
func TestAdminEndpointsRequireSuperAdmin(t *testing.T) {
	env := testutil.New(t)
	farmer := env.Register("01300000015", "secret123", "Farm")
	victim := env.Register("01300000016", "secret123", "Other Farm")

	payment := submitPayment(t, env, victim.Access, "monthly", "PRIV-1", 150)

	cases := []struct {
		method, path string
	}{
		{http.MethodGet, "/api/v1/admin/payments"},
		{http.MethodPost, fmt.Sprintf("/api/v1/admin/payments/%d/confirm", payment.ID)},
		{http.MethodPost, fmt.Sprintf("/api/v1/admin/payments/%d/reject", payment.ID)},
	}
	for _, tc := range cases {
		var body any
		if tc.method == http.MethodPost {
			body = map[string]string{"note": "nope"}
		}
		resp := env.Do(tc.method, tc.path, farmer.Access, body).ExpectStatus(http.StatusForbidden)
		if code := resp.ErrorCode(); code != "forbidden" {
			t.Errorf("%s %s: code = %q, want forbidden", tc.method, tc.path, code)
		}
	}
	// And the payment is untouched.
	if _, err := env.Pool.Exec(context.Background(),
		`SELECT 1 FROM payments WHERE id = $1 AND status = 'pending'`, payment.ID); err != nil {
		t.Fatalf("payment should still be pending: %v", err)
	}
}

func TestAdminCanListPendingPaymentsAcrossFarms(t *testing.T) {
	env := testutil.New(t)
	one := env.Register("01300000017", "secret123", "Farm One")
	two := env.Register("01300000018", "secret123", "Farm Two")
	ops := superAdmin(t, env, "01300000019")

	submitPayment(t, env, one.Access, "monthly", "QUEUE-1", 150)
	paid := submitPayment(t, env, two.Access, "yearly", "QUEUE-2", 1500)
	env.Do(http.MethodPost, fmt.Sprintf("/api/v1/admin/payments/%d/confirm", paid.ID), ops.Access, nil).
		ExpectStatus(http.StatusOK)

	var queue struct {
		Data []paymentDTO `json:"data"`
	}
	env.Do(http.MethodGet, "/api/v1/admin/payments?status=pending", ops.Access, nil).
		ExpectStatus(http.StatusOK).JSON(&queue)
	if len(queue.Data) != 1 || queue.Data[0].InstapayRef != "QUEUE-1" {
		t.Errorf("pending queue = %+v, want only QUEUE-1", queue.Data)
	}

	var all struct {
		Data []paymentDTO `json:"data"`
	}
	env.Do(http.MethodGet, "/api/v1/admin/payments", ops.Access, nil).
		ExpectStatus(http.StatusOK).JSON(&all)
	if len(all.Data) != 2 {
		t.Errorf("unfiltered queue has %d rows, want 2", len(all.Data))
	}
}

func TestConfirmUnknownPaymentIs404(t *testing.T) {
	env := testutil.New(t)
	ops := superAdmin(t, env, "01300000020")

	env.Do(http.MethodPost, "/api/v1/admin/payments/999999/confirm", ops.Access, nil).
		ExpectStatus(http.StatusNotFound)
	env.Do(http.MethodPost, "/api/v1/admin/payments/not-a-number/confirm", ops.Access, nil).
		ExpectStatus(http.StatusNotFound)
}
