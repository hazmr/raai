package server_test

import (
	"fmt"
	"net/http"
	"testing"

	"raai/internal/testutil"
)

type memberDTO struct {
	UserID      int32  `json:"userId"`
	PhoneNumber string `json:"phoneNumber"`
	Role        string `json:"role"`
}

func listMembers(t *testing.T, env *testutil.Env, token string) []memberDTO {
	t.Helper()
	var list struct {
		Data []memberDTO `json:"data"`
	}
	env.Do(http.MethodGet, "/api/v1/farm/members", token, nil).
		ExpectStatus(http.StatusOK).JSON(&list)
	return list.Data
}

func TestAdminListsAndAddsMembers(t *testing.T) {
	env := testutil.New(t)
	admin := env.Register("01600000001", "secret123", "Farm")

	if got := listMembers(t, env, admin.Access); len(got) != 1 || got[0].Role != "admin" {
		t.Fatalf("initial members = %+v, want just the admin", got)
	}

	var added memberDTO
	env.Do(http.MethodPost, "/api/v1/farm/members", admin.Access, map[string]string{
		"phoneNumber": "01600000002",
		"password":    "secret123",
	}).ExpectStatus(http.StatusCreated).JSON(&added)

	if added.Role != "farmer" {
		t.Errorf("new member role = %q, want farmer", added.Role)
	}
	if got := listMembers(t, env, admin.Access); len(got) != 2 {
		t.Errorf("members = %d, want 2", len(got))
	}
}

func TestAddingMemberValidatesCredentials(t *testing.T) {
	env := testutil.New(t)
	admin := env.Register("01600000003", "secret123", "Farm")

	cases := map[string]map[string]string{
		"missing phone":  {"phoneNumber": " ", "password": "secret123"},
		"short password": {"phoneNumber": "01600000004", "password": "abc"},
	}
	for name, body := range cases {
		resp := env.Do(http.MethodPost, "/api/v1/farm/members", admin.Access, body).
			ExpectStatus(http.StatusUnprocessableEntity)
		if code := resp.ErrorCode(); code != "validation_error" {
			t.Errorf("%s: code = %q, want validation_error", name, code)
		}
	}
}

// One phone belongs to one farm; a number already in use can't be re-added.
func TestAddingAnExistingPhoneConflicts(t *testing.T) {
	env := testutil.New(t)
	admin := env.Register("01600000005", "secret123", "Farm One")
	env.Register("01600000006", "secret123", "Farm Two")

	resp := env.Do(http.MethodPost, "/api/v1/farm/members", admin.Access, map[string]string{
		"phoneNumber": "01600000006",
		"password":    "secret123",
	}).ExpectStatus(http.StatusConflict)
	if code := resp.ErrorCode(); code != "conflict" {
		t.Errorf("code = %q, want conflict", code)
	}
}

func TestRemovingMemberEndsTheirAccess(t *testing.T) {
	env := testutil.New(t)
	admin := env.Register("01600000007", "secret123", "Farm")
	env.Activate(admin.FarmID)
	memberToken := addMember(t, env, admin.Access, "01600000008")

	env.Do(http.MethodGet, "/api/v1/animals", memberToken, nil).ExpectStatus(http.StatusOK)

	members := listMembers(t, env, admin.Access)
	var memberID int32
	for _, m := range members {
		if m.Role == "farmer" {
			memberID = m.UserID
		}
	}
	if memberID == 0 {
		t.Fatalf("no farmer found in %+v", members)
	}

	env.Do(http.MethodDelete, fmt.Sprintf("/api/v1/farm/members/%d", memberID), admin.Access, nil).
		ExpectStatus(http.StatusNoContent)

	// Without a membership the token no longer resolves to a farm.
	env.Do(http.MethodGet, "/api/v1/animals", memberToken, nil).ExpectStatus(http.StatusUnauthorized)
	if got := listMembers(t, env, admin.Access); len(got) != 1 {
		t.Errorf("members = %d, want 1 after removal", len(got))
	}
}

// The admin must not be able to remove themselves and orphan the farm.
func TestAdminCannotBeRemoved(t *testing.T) {
	env := testutil.New(t)
	admin := env.Register("01600000009", "secret123", "Farm")

	resp := env.Do(http.MethodDelete, fmt.Sprintf("/api/v1/farm/members/%d", admin.UserID), admin.Access, nil).
		ExpectStatus(http.StatusNotFound)
	if code := resp.ErrorCode(); code != "not_found" {
		t.Errorf("code = %q, want not_found", code)
	}
	if got := listMembers(t, env, admin.Access); len(got) != 1 {
		t.Errorf("members = %d, want the admin still present", len(got))
	}
}

func TestRemovingAnotherFarmsMemberIs404(t *testing.T) {
	env := testutil.New(t)
	one := env.Register("01600000010", "secret123", "Farm One")
	two := env.Register("01600000011", "secret123", "Farm Two")
	addMember(t, env, two.Access, "01600000012")

	var victim int32
	for _, m := range listMembers(t, env, two.Access) {
		if m.Role == "farmer" {
			victim = m.UserID
		}
	}
	env.Do(http.MethodDelete, fmt.Sprintf("/api/v1/farm/members/%d", victim), one.Access, nil).
		ExpectStatus(http.StatusNotFound)

	if got := listMembers(t, env, two.Access); len(got) != 2 {
		t.Errorf("farm two members = %d, want 2 (untouched)", len(got))
	}
}
