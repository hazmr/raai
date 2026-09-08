package server_test

import (
	"fmt"
	"net/http"
	"testing"

	"raai/internal/testutil"
)

// The herd is behind the paywall; auth, billing and farm management are not, so a
// lapsed admin can still log in and pay.
func TestGateBlocksHerdUntilSubscriptionIsActive(t *testing.T) {
	env := testutil.New(t)
	acct := env.Register("01100000001", "secret123", "Farm")

	resp := env.Do(http.MethodGet, "/api/v1/animals", acct.Access, nil).
		ExpectStatus(http.StatusPaymentRequired)
	if code := resp.ErrorCode(); code != "subscription_required" {
		t.Errorf("code = %q, want subscription_required", code)
	}

	env.Activate(acct.FarmID)
	env.Do(http.MethodGet, "/api/v1/animals", acct.Access, nil).ExpectStatus(http.StatusOK)
}

func TestUnpaidAdminCanStillReachBillingAndMembers(t *testing.T) {
	env := testutil.New(t)
	acct := env.Register("01100000002", "secret123", "Farm")

	for _, path := range []string{"/api/v1/me", "/api/v1/billing/plans", "/api/v1/billing/status", "/api/v1/farm/members"} {
		env.Do(http.MethodGet, path, acct.Access, nil).ExpectStatus(http.StatusOK)
	}
}

func TestGateCoversEveryHerdRoute(t *testing.T) {
	env := testutil.New(t)
	acct := env.Register("01100000003", "secret123", "Farm")

	// Seed one animal while paid, then let the subscription lapse.
	env.Activate(acct.FarmID)
	animalID := env.CreateAnimal(acct.Access, "TAG-LAPSE")
	if _, err := env.Pool.Exec(t.Context(),
		`UPDATE subscriptions SET current_period_end = now() - interval '1 day' WHERE farm_id = $1`,
		acct.FarmID); err != nil {
		t.Fatalf("expire subscription: %v", err)
	}

	cases := []struct {
		method, path string
		body         any
	}{
		{http.MethodGet, "/api/v1/animals", nil},
		{http.MethodPost, "/api/v1/animals", map[string]string{"barcode": "TAG-NEW"}},
		{http.MethodGet, fmt.Sprintf("/api/v1/animals/%d", animalID), nil},
		{http.MethodPatch, fmt.Sprintf("/api/v1/animals/%d", animalID), map[string]string{"barcode": "TAG-X"}},
		{http.MethodDelete, fmt.Sprintf("/api/v1/animals/%d", animalID), nil},
		{http.MethodGet, fmt.Sprintf("/api/v1/animals/%d/notes", animalID), nil},
		{http.MethodPost, fmt.Sprintf("/api/v1/animals/%d/notes", animalID), map[string]string{"body": "note"}},
		{http.MethodGet, "/api/v1/invites", nil},
		{http.MethodPost, "/api/v1/invites", map[string]string{"doctorLabel": "Dr"}},
	}
	for _, tc := range cases {
		resp := env.Do(tc.method, tc.path, acct.Access, tc.body)
		if resp.Status != http.StatusPaymentRequired {
			t.Errorf("%s %s: status = %d, want 402", tc.method, tc.path, resp.Status)
		}
	}
}

// The gate keys off the farm, so a plain member of a paid farm gets through and a
// member of a lapsed farm does not — regardless of who is calling.
func TestGateKeysOffTheFarmNotTheCaller(t *testing.T) {
	env := testutil.New(t)
	admin := env.Register("01100000004", "secret123", "Farm")
	env.Activate(admin.FarmID)

	env.Do(http.MethodPost, "/api/v1/farm/members", admin.Access, map[string]string{
		"phoneNumber": "01100000005",
		"password":    "secret123",
	}).ExpectStatus(http.StatusCreated)

	var tokens struct {
		AccessToken string `json:"accessToken"`
	}
	env.Do(http.MethodPost, "/api/v1/auth/login", "", map[string]string{
		"phoneNumber": "01100000005",
		"password":    "secret123",
	}).ExpectStatus(http.StatusOK).JSON(&tokens)

	env.Do(http.MethodGet, "/api/v1/animals", tokens.AccessToken, nil).ExpectStatus(http.StatusOK)

	// A plain member is not the farm admin: management stays closed to them.
	for _, path := range []string{"/api/v1/farm/members", "/api/v1/invites"} {
		resp := env.Do(http.MethodGet, path, tokens.AccessToken, nil).
			ExpectStatus(http.StatusForbidden)
		if code := resp.ErrorCode(); code != "forbidden" {
			t.Errorf("%s: code = %q, want forbidden", path, code)
		}
	}
}

// Tenancy: one farm must never see, edit or delete another farm's herd.
func TestFarmsAreIsolated(t *testing.T) {
	env := testutil.New(t)

	one := env.Register("01100000006", "secret123", "Farm One")
	two := env.Register("01100000007", "secret123", "Farm Two")
	env.Activate(one.FarmID)
	env.Activate(two.FarmID)

	animalID := env.CreateAnimal(one.Access, "TAG-PRIVATE")
	env.Do(http.MethodPost, fmt.Sprintf("/api/v1/animals/%d/notes", animalID), one.Access,
		map[string]string{"body": "farm one's note"}).ExpectStatus(http.StatusCreated)

	var list struct {
		Data []struct {
			ID int32 `json:"id"`
		} `json:"data"`
	}
	env.Do(http.MethodGet, "/api/v1/animals", two.Access, nil).
		ExpectStatus(http.StatusOK).JSON(&list)
	if len(list.Data) != 0 {
		t.Errorf("farm two sees %d animals, want 0", len(list.Data))
	}

	// Direct addressing is a 404, not a 403: the resource must not even be confirmed.
	cases := []struct {
		method, path string
		body         any
	}{
		{http.MethodGet, fmt.Sprintf("/api/v1/animals/%d", animalID), nil},
		{http.MethodPatch, fmt.Sprintf("/api/v1/animals/%d", animalID), map[string]string{"barcode": "STOLEN"}},
		{http.MethodDelete, fmt.Sprintf("/api/v1/animals/%d", animalID), nil},
		{http.MethodGet, fmt.Sprintf("/api/v1/animals/%d/notes", animalID), nil},
		{http.MethodPost, fmt.Sprintf("/api/v1/animals/%d/notes", animalID), map[string]string{"body": "intruder"}},
	}
	for _, tc := range cases {
		resp := env.Do(tc.method, tc.path, two.Access, tc.body)
		if resp.Status != http.StatusNotFound {
			t.Errorf("%s %s: status = %d, want 404", tc.method, tc.path, resp.Status)
		}
	}

	// The same ear tag may exist in both farms — uniqueness is per farm.
	env.Do(http.MethodPost, "/api/v1/animals", two.Access, map[string]string{"barcode": "TAG-PRIVATE"}).
		ExpectStatus(http.StatusCreated)
}

func TestBarcodeLookupIsScopedToTheFarm(t *testing.T) {
	env := testutil.New(t)
	one := env.Register("01100000008", "secret123", "Farm One")
	two := env.Register("01100000009", "secret123", "Farm Two")
	env.Activate(one.FarmID)
	env.Activate(two.FarmID)
	env.CreateAnimal(one.Access, "TAG-SCAN")

	var found struct {
		Data []struct {
			Barcode string `json:"barcode"`
		} `json:"data"`
	}
	env.Do(http.MethodGet, "/api/v1/animals?barcode=TAG-SCAN", one.Access, nil).
		ExpectStatus(http.StatusOK).JSON(&found)
	if len(found.Data) != 1 || found.Data[0].Barcode != "TAG-SCAN" {
		t.Fatalf("owner lookup = %+v, want one TAG-SCAN", found.Data)
	}

	// A miss is an empty list, not a 404 — the app then offers "register this tag".
	var missing struct {
		Data []struct{} `json:"data"`
	}
	env.Do(http.MethodGet, "/api/v1/animals?barcode=TAG-SCAN", two.Access, nil).
		ExpectStatus(http.StatusOK).JSON(&missing)
	if len(missing.Data) != 0 {
		t.Errorf("other farm's lookup returned %d rows, want 0", len(missing.Data))
	}
}

func TestDuplicateBarcodeInSameFarmConflicts(t *testing.T) {
	env := testutil.New(t)
	acct := env.Register("01100000010", "secret123", "Farm")
	env.Activate(acct.FarmID)
	env.CreateAnimal(acct.Access, "TAG-DUP")

	resp := env.Do(http.MethodPost, "/api/v1/animals", acct.Access,
		map[string]string{"barcode": "TAG-DUP"}).ExpectStatus(http.StatusConflict)
	if code := resp.ErrorCode(); code != "conflict" {
		t.Errorf("code = %q, want conflict", code)
	}
}

func TestAnimalsPaginateWithCursor(t *testing.T) {
	env := testutil.New(t)
	acct := env.Register("01100000011", "secret123", "Farm")
	env.Activate(acct.FarmID)

	for i := 0; i < 5; i++ {
		env.CreateAnimal(acct.Access, fmt.Sprintf("TAG-%02d", i))
	}

	type page struct {
		Data []struct {
			ID      int32  `json:"id"`
			Barcode string `json:"barcode"`
		} `json:"data"`
		NextCursor *string `json:"nextCursor"`
	}

	seen := map[int32]bool{}
	var first page
	env.Do(http.MethodGet, "/api/v1/animals?limit=2", acct.Access, nil).
		ExpectStatus(http.StatusOK).JSON(&first)
	if len(first.Data) != 2 {
		t.Fatalf("first page has %d rows, want 2", len(first.Data))
	}
	if first.NextCursor == nil {
		t.Fatal("first page has no nextCursor")
	}
	for _, a := range first.Data {
		seen[a.ID] = true
	}

	cursor := *first.NextCursor
	for range 4 { // walk to the end, guarding against a cursor that never advances
		var next page
		env.Do(http.MethodGet, "/api/v1/animals?limit=2&cursor="+cursor, acct.Access, nil).
			ExpectStatus(http.StatusOK).JSON(&next)
		for _, a := range next.Data {
			if seen[a.ID] {
				t.Fatalf("animal %d returned on two pages", a.ID)
			}
			seen[a.ID] = true
		}
		if next.NextCursor == nil {
			break
		}
		cursor = *next.NextCursor
	}
	if len(seen) != 5 {
		t.Errorf("paged over %d animals, want 5", len(seen))
	}
}
