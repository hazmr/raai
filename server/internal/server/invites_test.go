package server_test

import (
	"context"
	"fmt"
	"net/http"
	"testing"
	"time"

	"raai/internal/testutil"
)

type inviteDTO struct {
	ID          int32  `json:"id"`
	DoctorLabel string `json:"doctorLabel"`
	Token       string `json:"token"`
	Status      string `json:"status"`
	NoteCount   int64  `json:"noteCount"`
}

type doctorSession struct {
	AccessToken string `json:"accessToken"`
	DoctorLabel string `json:"doctorLabel"`
	Farm        struct {
		ID   int32  `json:"id"`
		Name string `json:"name"`
	} `json:"farm"`
}

func createInvite(t *testing.T, env *testutil.Env, token, label string) inviteDTO {
	t.Helper()
	var inv inviteDTO
	env.Do(http.MethodPost, "/api/v1/invites", token, map[string]any{"doctorLabel": label}).
		ExpectStatus(http.StatusCreated).JSON(&inv)
	return inv
}

func redeem(t *testing.T, env *testutil.Env, token string) doctorSession {
	t.Helper()
	var sess doctorSession
	env.Do(http.MethodPost, "/api/v1/doctor/redeem", "", map[string]string{"token": token}).
		ExpectStatus(http.StatusOK).JSON(&sess)
	return sess
}

// The whole visiting-vet flow: invite → QR redeem → notes on the farm's herd.
func TestDoctorRedeemsInviteAndWritesNotes(t *testing.T) {
	env := testutil.New(t)
	admin := env.Register("01400000001", "secret123", "مزرعة الأمل")
	env.Activate(admin.FarmID)
	animalID := env.CreateAnimal(admin.Access, "TAG-VET")

	invite := createInvite(t, env, admin.Access, "د. سارة")
	if invite.Token == "" {
		t.Fatal("invite has no token — nothing to encode in the QR")
	}
	if invite.Status != "active" {
		t.Errorf("status = %q, want active", invite.Status)
	}

	sess := redeem(t, env, invite.Token)
	if sess.AccessToken == "" {
		t.Fatal("redeem returned no access token")
	}
	if sess.DoctorLabel != "د. سارة" {
		t.Errorf("doctorLabel = %q, want the invited name", sess.DoctorLabel)
	}
	if sess.Farm.ID != admin.FarmID {
		t.Errorf("farm id = %d, want %d", sess.Farm.ID, admin.FarmID)
	}

	// The doctor sees the farm's herd and can write a note on it.
	env.Do(http.MethodGet, "/api/v1/animals", sess.AccessToken, nil).ExpectStatus(http.StatusOK)

	var note noteDTO
	env.Do(http.MethodPost, fmt.Sprintf("/api/v1/animals/%d/notes", animalID), sess.AccessToken,
		map[string]string{"body": "حرارة مرتفعة — بدأت المضاد الحيوي"}).
		ExpectStatus(http.StatusCreated).JSON(&note)

	if note.AuthorKind != "doctor" {
		t.Errorf("authorKind = %q, want doctor", note.AuthorKind)
	}
	if note.AuthorLabel != "د. سارة" {
		t.Errorf("authorLabel = %q, want the doctor's name", note.AuthorLabel)
	}
	if note.InviteID == nil || *note.InviteID != invite.ID {
		t.Errorf("inviteId = %v, want %d", note.InviteID, invite.ID)
	}
}

// Ending an invite revokes the doctor's live session on the very next request.
func TestEndingInviteRevokesDoctorImmediately(t *testing.T) {
	env := testutil.New(t)
	admin := env.Register("01400000002", "secret123", "Farm")
	env.Activate(admin.FarmID)
	animalID := env.CreateAnimal(admin.Access, "TAG-REVOKE")

	invite := createInvite(t, env, admin.Access, "Dr Visit")
	sess := redeem(t, env, invite.Token)
	env.Do(http.MethodGet, "/api/v1/animals", sess.AccessToken, nil).ExpectStatus(http.StatusOK)

	var ended inviteDTO
	env.Do(http.MethodPost, fmt.Sprintf("/api/v1/invites/%d/end", invite.ID), admin.Access, nil).
		ExpectStatus(http.StatusOK).JSON(&ended)
	if ended.Status != "ended" {
		t.Errorf("status = %q, want ended", ended.Status)
	}

	// The unexpired access token no longer works — the invite is re-checked per request.
	for _, path := range []string{
		"/api/v1/animals",
		fmt.Sprintf("/api/v1/animals/%d/notes", animalID),
	} {
		resp := env.Do(http.MethodGet, path, sess.AccessToken, nil).
			ExpectStatus(http.StatusUnauthorized)
		if code := resp.ErrorCode(); code != "unauthorized" {
			t.Errorf("%s: code = %q, want unauthorized", path, code)
		}
	}

	// And the QR can't be redeemed again.
	env.Do(http.MethodPost, "/api/v1/doctor/redeem", "", map[string]string{"token": invite.Token}).
		ExpectStatus(http.StatusUnauthorized)
}

// Notes written during a visit survive the visit ending — that is the history.
func TestDoctorNotesSurviveEndedInvite(t *testing.T) {
	env := testutil.New(t)
	admin := env.Register("01400000003", "secret123", "Farm")
	env.Activate(admin.FarmID)
	animalID := env.CreateAnimal(admin.Access, "TAG-HISTORY")

	invite := createInvite(t, env, admin.Access, "Dr Past")
	sess := redeem(t, env, invite.Token)
	env.Do(http.MethodPost, fmt.Sprintf("/api/v1/animals/%d/notes", animalID), sess.AccessToken,
		map[string]string{"body": "treated for mastitis"}).ExpectStatus(http.StatusCreated)
	env.Do(http.MethodPost, fmt.Sprintf("/api/v1/invites/%d/end", invite.ID), admin.Access, nil).
		ExpectStatus(http.StatusOK)

	var notes struct {
		Data []noteDTO `json:"data"`
	}
	env.Do(http.MethodGet, fmt.Sprintf("/api/v1/animals/%d/notes", animalID), admin.Access, nil).
		ExpectStatus(http.StatusOK).JSON(&notes)

	if len(notes.Data) != 1 {
		t.Fatalf("animal has %d notes, want 1", len(notes.Data))
	}
	if notes.Data[0].AuthorLabel != "Dr Past" {
		t.Errorf("authorLabel = %q, want the doctor's name stamped at write time", notes.Data[0].AuthorLabel)
	}

	// The invite history shows what that doctor wrote.
	var list struct {
		Data []inviteDTO `json:"data"`
	}
	env.Do(http.MethodGet, "/api/v1/invites", admin.Access, nil).
		ExpectStatus(http.StatusOK).JSON(&list)
	if len(list.Data) != 1 || list.Data[0].NoteCount != 1 {
		t.Errorf("invite history = %+v, want one invite with noteCount 1", list.Data)
	}
}

// A doctor is note-only: they may register a scanned tag but not edit the herd.
func TestDoctorCannotEditOrDeleteAnimals(t *testing.T) {
	env := testutil.New(t)
	admin := env.Register("01400000004", "secret123", "Farm")
	env.Activate(admin.FarmID)
	animalID := env.CreateAnimal(admin.Access, "TAG-READONLY")

	sess := redeem(t, env, createInvite(t, env, admin.Access, "Dr Limited").Token)

	resp := env.Do(http.MethodPatch, fmt.Sprintf("/api/v1/animals/%d", animalID), sess.AccessToken,
		map[string]string{"barcode": "TAG-CHANGED"}).ExpectStatus(http.StatusForbidden)
	if code := resp.ErrorCode(); code != "forbidden" {
		t.Errorf("patch code = %q, want forbidden", code)
	}
	env.Do(http.MethodDelete, fmt.Sprintf("/api/v1/animals/%d", animalID), sess.AccessToken, nil).
		ExpectStatus(http.StatusForbidden)

	// Registering a freshly-scanned ear tag is allowed.
	env.Do(http.MethodPost, "/api/v1/animals", sess.AccessToken,
		map[string]string{"barcode": "TAG-SCANNED-BY-VET"}).ExpectStatus(http.StatusCreated)
}

// Farm management is the admin's, never the visiting doctor's.
func TestDoctorCannotManageFarm(t *testing.T) {
	env := testutil.New(t)
	admin := env.Register("01400000005", "secret123", "Farm")
	env.Activate(admin.FarmID)
	sess := redeem(t, env, createInvite(t, env, admin.Access, "Dr Nosy").Token)

	cases := []struct {
		method, path string
		body         any
	}{
		{http.MethodGet, "/api/v1/invites", nil},
		{http.MethodPost, "/api/v1/invites", map[string]string{"doctorLabel": "Dr Second"}},
		{http.MethodGet, "/api/v1/farm/members", nil},
		{http.MethodPost, "/api/v1/farm/members", map[string]string{"phoneNumber": "01499999999", "password": "secret123"}},
	}
	for _, tc := range cases {
		resp := env.Do(tc.method, tc.path, sess.AccessToken, tc.body)
		if resp.Status != http.StatusForbidden {
			t.Errorf("%s %s: status = %d, want 403", tc.method, tc.path, resp.Status)
		}
	}
}

func TestRedeemRejectsUnknownAndEmptyTokens(t *testing.T) {
	env := testutil.New(t)

	for name, token := range map[string]string{
		"unknown": "no-such-invite-token",
		"empty":   "",
		"blank":   "   ",
	} {
		resp := env.Do(http.MethodPost, "/api/v1/doctor/redeem", "", map[string]string{"token": token}).
			ExpectStatus(http.StatusUnauthorized)
		if code := resp.ErrorCode(); code != "unauthorized" {
			t.Errorf("%s: code = %q, want unauthorized", name, code)
		}
	}
}

func TestRedeemRejectsExpiredInvite(t *testing.T) {
	env := testutil.New(t)
	admin := env.Register("01400000006", "secret123", "Farm")
	env.Activate(admin.FarmID)

	var invite inviteDTO
	env.Do(http.MethodPost, "/api/v1/invites", admin.Access, map[string]any{
		"doctorLabel": "Dr Expired",
		"expiresAt":   time.Now().Add(-time.Hour).UTC().Format(time.RFC3339),
	}).ExpectStatus(http.StatusCreated).JSON(&invite)

	env.Do(http.MethodPost, "/api/v1/doctor/redeem", "", map[string]string{"token": invite.Token}).
		ExpectStatus(http.StatusUnauthorized)
}

// A doctor cannot get in through a farm that has stopped paying.
func TestRedeemRequiresActiveSubscription(t *testing.T) {
	env := testutil.New(t)
	admin := env.Register("01400000007", "secret123", "Farm")
	env.Activate(admin.FarmID)
	invite := createInvite(t, env, admin.Access, "Dr Unpaid")

	if _, err := env.Pool.Exec(context.Background(),
		`UPDATE subscriptions SET current_period_end = now() - interval '1 day' WHERE farm_id = $1`,
		admin.FarmID); err != nil {
		t.Fatalf("expire subscription: %v", err)
	}

	resp := env.Do(http.MethodPost, "/api/v1/doctor/redeem", "", map[string]string{"token": invite.Token}).
		ExpectStatus(http.StatusPaymentRequired)
	if code := resp.ErrorCode(); code != "subscription_required" {
		t.Errorf("code = %q, want subscription_required", code)
	}
}

// A doctor's session is scoped to the farm that invited them.
func TestDoctorIsScopedToInvitingFarm(t *testing.T) {
	env := testutil.New(t)
	one := env.Register("01400000008", "secret123", "Farm One")
	two := env.Register("01400000009", "secret123", "Farm Two")
	env.Activate(one.FarmID)
	env.Activate(two.FarmID)

	otherAnimal := env.CreateAnimal(two.Access, "TAG-OTHER-FARM")
	sess := redeem(t, env, createInvite(t, env, one.Access, "Dr One").Token)

	env.Do(http.MethodGet, fmt.Sprintf("/api/v1/animals/%d", otherAnimal), sess.AccessToken, nil).
		ExpectStatus(http.StatusNotFound)
	env.Do(http.MethodPost, fmt.Sprintf("/api/v1/animals/%d/notes", otherAnimal), sess.AccessToken,
		map[string]string{"body": "should not land"}).ExpectStatus(http.StatusNotFound)
}

func TestInviteRequiresDoctorLabel(t *testing.T) {
	env := testutil.New(t)
	admin := env.Register("01400000010", "secret123", "Farm")
	env.Activate(admin.FarmID)

	resp := env.Do(http.MethodPost, "/api/v1/invites", admin.Access, map[string]string{"doctorLabel": "  "}).
		ExpectStatus(http.StatusUnprocessableEntity)
	if code := resp.ErrorCode(); code != "validation_error" {
		t.Errorf("code = %q, want validation_error", code)
	}
}

func TestEndingAnotherFarmsInviteIs404(t *testing.T) {
	env := testutil.New(t)
	one := env.Register("01400000011", "secret123", "Farm One")
	two := env.Register("01400000012", "secret123", "Farm Two")
	env.Activate(one.FarmID)
	env.Activate(two.FarmID)

	invite := createInvite(t, env, one.Access, "Dr One")
	env.Do(http.MethodPost, fmt.Sprintf("/api/v1/invites/%d/end", invite.ID), two.Access, nil).
		ExpectStatus(http.StatusNotFound)

	// Still usable by its own farm's doctor.
	redeem(t, env, invite.Token)
}
