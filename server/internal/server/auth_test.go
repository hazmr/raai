package server_test

import (
	"net/http"
	"testing"

	"raai/internal/testutil"
)

func TestRegisterCreatesFarmWithAdminMembership(t *testing.T) {
	env := testutil.New(t)

	var tokens struct {
		AccessToken  string `json:"accessToken"`
		RefreshToken string `json:"refreshToken"`
		TokenType    string `json:"tokenType"`
	}
	env.Do(http.MethodPost, "/api/v1/auth/register", "", map[string]string{
		"phoneNumber": "01000000001",
		"password":    "secret123",
		"farmName":    "مزرعة النور",
	}).ExpectStatus(http.StatusCreated).JSON(&tokens)

	if tokens.AccessToken == "" || tokens.RefreshToken == "" {
		t.Fatal("register returned empty tokens")
	}
	if tokens.TokenType != "Bearer" {
		t.Errorf("TokenType = %q, want Bearer", tokens.TokenType)
	}

	var me struct {
		PhoneNumber string `json:"phoneNumber"`
		IsAdmin     bool   `json:"isAdmin"`
		FarmRole    string `json:"farmRole"`
		Farm        struct {
			ID   int32  `json:"id"`
			Name string `json:"name"`
		} `json:"farm"`
	}
	env.Do(http.MethodGet, "/api/v1/me", tokens.AccessToken, nil).
		ExpectStatus(http.StatusOK).JSON(&me)

	if me.PhoneNumber != "01000000001" {
		t.Errorf("phoneNumber = %q", me.PhoneNumber)
	}
	if me.FarmRole != "admin" {
		t.Errorf("farmRole = %q, want admin", me.FarmRole)
	}
	if me.Farm.Name != "مزرعة النور" {
		t.Errorf("farm name = %q, want the Arabic name to survive round-trip", me.Farm.Name)
	}
	// Farm admin is not the same as app super-admin.
	if me.IsAdmin {
		t.Error("a self-registered user became an app super-admin")
	}
}

func TestRegisterDefaultsFarmName(t *testing.T) {
	env := testutil.New(t)

	acct := env.Register("01000000002", "secret123", "")
	var me struct {
		Farm struct {
			Name string `json:"name"`
		} `json:"farm"`
	}
	env.Do(http.MethodGet, "/api/v1/me", acct.Access, nil).
		ExpectStatus(http.StatusOK).JSON(&me)

	if me.Farm.Name == "" {
		t.Error("farm name is empty when registration omits it")
	}
}

func TestRegisterRejectsDuplicatePhone(t *testing.T) {
	env := testutil.New(t)
	env.Register("01000000003", "secret123", "First")

	resp := env.Do(http.MethodPost, "/api/v1/auth/register", "", map[string]string{
		"phoneNumber": "01000000003",
		"password":    "another1",
		"farmName":    "Second",
	}).ExpectStatus(http.StatusConflict)

	if code := resp.ErrorCode(); code != "conflict" {
		t.Errorf("code = %q, want conflict", code)
	}
}

func TestRegisterValidatesCredentials(t *testing.T) {
	env := testutil.New(t)

	cases := map[string]map[string]string{
		"missing phone":  {"phoneNumber": "", "password": "secret123"},
		"short password": {"phoneNumber": "01000000004", "password": "abc"},
	}
	for name, body := range cases {
		resp := env.Do(http.MethodPost, "/api/v1/auth/register", "", body).
			ExpectStatus(http.StatusUnprocessableEntity)
		if code := resp.ErrorCode(); code != "validation_error" {
			t.Errorf("%s: code = %q, want validation_error", name, code)
		}
	}
}

func TestLoginRejectsBadCredentials(t *testing.T) {
	env := testutil.New(t)
	env.Register("01000000005", "secret123", "Farm")

	cases := map[string]map[string]string{
		"wrong password": {"phoneNumber": "01000000005", "password": "not-it-at-all"},
		"unknown phone":  {"phoneNumber": "01099999999", "password": "secret123"},
	}
	for name, body := range cases {
		resp := env.Do(http.MethodPost, "/api/v1/auth/login", "", body).
			ExpectStatus(http.StatusUnauthorized)
		if code := resp.ErrorCode(); code != "unauthorized" {
			t.Errorf("%s: code = %q, want unauthorized", name, code)
		}
	}
}

func TestLoginReturnsUsableToken(t *testing.T) {
	env := testutil.New(t)
	env.Register("01000000006", "secret123", "Farm")

	var tokens struct {
		AccessToken string `json:"accessToken"`
	}
	env.Do(http.MethodPost, "/api/v1/auth/login", "", map[string]string{
		"phoneNumber": "01000000006",
		"password":    "secret123",
	}).ExpectStatus(http.StatusOK).JSON(&tokens)

	env.Do(http.MethodGet, "/api/v1/me", tokens.AccessToken, nil).ExpectStatus(http.StatusOK)
}

// The refresh token rotates on every use, so a stolen copy dies at first replay.
func TestRefreshRotatesAndInvalidatesTheOldToken(t *testing.T) {
	env := testutil.New(t)
	acct := env.Register("01000000007", "secret123", "Farm")

	var rotated struct {
		AccessToken  string `json:"accessToken"`
		RefreshToken string `json:"refreshToken"`
	}
	env.Do(http.MethodPost, "/api/v1/auth/refresh", "", map[string]string{
		"refreshToken": acct.Refresh,
	}).ExpectStatus(http.StatusOK).JSON(&rotated)

	if rotated.RefreshToken == acct.Refresh {
		t.Fatal("refresh token was not rotated")
	}
	env.Do(http.MethodGet, "/api/v1/me", rotated.AccessToken, nil).ExpectStatus(http.StatusOK)

	// Replaying the consumed token must fail.
	resp := env.Do(http.MethodPost, "/api/v1/auth/refresh", "", map[string]string{
		"refreshToken": acct.Refresh,
	}).ExpectStatus(http.StatusUnauthorized)
	if code := resp.ErrorCode(); code != "unauthorized" {
		t.Errorf("code = %q, want unauthorized", code)
	}
}

func TestRefreshRejectsUnknownToken(t *testing.T) {
	env := testutil.New(t)
	env.Register("01000000008", "secret123", "Farm")

	env.Do(http.MethodPost, "/api/v1/auth/refresh", "", map[string]string{
		"refreshToken": "not-a-real-refresh-token",
	}).ExpectStatus(http.StatusUnauthorized)

	env.Do(http.MethodPost, "/api/v1/auth/refresh", "", map[string]string{
		"refreshToken": "",
	}).ExpectStatus(http.StatusUnauthorized)
}

func TestLogoutClearsRefreshToken(t *testing.T) {
	env := testutil.New(t)
	acct := env.Register("01000000009", "secret123", "Farm")

	env.Do(http.MethodPost, "/api/v1/auth/logout", acct.Access, nil).
		ExpectStatus(http.StatusNoContent)

	env.Do(http.MethodPost, "/api/v1/auth/refresh", "", map[string]string{
		"refreshToken": acct.Refresh,
	}).ExpectStatus(http.StatusUnauthorized)
}

func TestProtectedRoutesRejectBadTokens(t *testing.T) {
	env := testutil.New(t)

	cases := map[string]string{
		"no token":      "",
		"garbage token": "not.a.jwt",
		// Signed with a different key by another deployment.
		"foreign token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9." +
			"eyJzdWIiOiIxIiwiaXNzIjoicmFhaSIsImF1ZCI6WyJyYWFpLWFwcCJdLCJleHAiOjQxMDI0NDQ4MDB9." +
			"ZmFrZS1zaWduYXR1cmUtdGhhdC13aWxsLW5vdC12ZXJpZnk",
	}
	for name, token := range cases {
		resp := env.Do(http.MethodGet, "/api/v1/me", token, nil).
			ExpectStatus(http.StatusUnauthorized)
		if code := resp.ErrorCode(); code != "unauthorized" {
			t.Errorf("%s: code = %q, want unauthorized", name, code)
		}
	}
}

// A token stays valid only while the account behind it does.
func TestTokenStopsWorkingWhenAccountIsDeleted(t *testing.T) {
	env := testutil.New(t)
	acct := env.Register("01000000010", "secret123", "Farm")

	if _, err := env.Pool.Exec(t.Context(), `DELETE FROM users WHERE id = $1`, acct.UserID); err != nil {
		t.Fatalf("delete user: %v", err)
	}
	env.Do(http.MethodGet, "/api/v1/me", acct.Access, nil).ExpectStatus(http.StatusUnauthorized)
}

func TestHealthAndReadinessProbes(t *testing.T) {
	env := testutil.New(t)

	env.Do(http.MethodGet, "/healthz", "", nil).ExpectStatus(http.StatusOK)
	env.Do(http.MethodGet, "/readyz", "", nil).ExpectStatus(http.StatusOK)
}

func TestMalformedJSONIsRejected(t *testing.T) {
	env := testutil.New(t)

	req, err := http.NewRequest(http.MethodPost, env.Server.URL+"/api/v1/auth/login",
		http.NoBody)
	if err != nil {
		t.Fatalf("build request: %v", err)
	}
	resp, err := env.Client.Do(req)
	if err != nil {
		t.Fatalf("send: %v", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusBadRequest {
		t.Errorf("empty body status = %d, want 400", resp.StatusCode)
	}
}
