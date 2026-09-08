package auth

import (
	"testing"
	"time"
)

func newTM(ttl time.Duration) *TokenManager {
	return NewTokenManager("test-signing-key", "raai", "raai-app", ttl)
}

func TestIssueUserRoundTrip(t *testing.T) {
	tm := newTM(time.Hour)

	token, exp, err := tm.IssueUser(7, "01000000000", 3, RoleAdmin)
	if err != nil {
		t.Fatalf("IssueUser: %v", err)
	}
	if time.Until(exp) <= 0 {
		t.Fatalf("expiry %v is not in the future", exp)
	}

	claims, err := tm.Parse(token)
	if err != nil {
		t.Fatalf("Parse: %v", err)
	}
	if claims.Kind != KindUser {
		t.Errorf("Kind = %q, want %q", claims.Kind, KindUser)
	}
	if claims.Farm != 3 {
		t.Errorf("Farm = %d, want 3", claims.Farm)
	}
	if claims.FRole != RoleAdmin {
		t.Errorf("FRole = %q, want %q", claims.FRole, RoleAdmin)
	}
	if claims.Phone != "01000000000" {
		t.Errorf("Phone = %q, want 01000000000", claims.Phone)
	}
	uid, err := claims.SubjectID()
	if err != nil || uid != 7 {
		t.Errorf("SubjectID() = %d, %v; want 7, nil", uid, err)
	}
}

func TestIssueDoctorCarriesInviteID(t *testing.T) {
	tm := newTM(time.Hour)

	token, _, err := tm.IssueDoctor(42, 3)
	if err != nil {
		t.Fatalf("IssueDoctor: %v", err)
	}
	claims, err := tm.Parse(token)
	if err != nil {
		t.Fatalf("Parse: %v", err)
	}
	if claims.Kind != KindDoctor {
		t.Errorf("Kind = %q, want %q", claims.Kind, KindDoctor)
	}
	if claims.Inv != 42 {
		t.Errorf("Inv = %d, want 42", claims.Inv)
	}
	if claims.FRole != RoleDoctor {
		t.Errorf("FRole = %q, want %q", claims.FRole, RoleDoctor)
	}
	// A doctor has no user row: the subject is the invite id.
	if sub, _ := claims.SubjectID(); sub != 42 {
		t.Errorf("SubjectID() = %d, want 42", sub)
	}
}

func TestParseRejectsForeignKey(t *testing.T) {
	token, _, err := newTM(time.Hour).IssueUser(1, "0100", 1, RoleFarmer)
	if err != nil {
		t.Fatalf("IssueUser: %v", err)
	}
	other := NewTokenManager("a-different-key", "raai", "raai-app", time.Hour)
	if _, err := other.Parse(token); err == nil {
		t.Fatal("Parse accepted a token signed with another key")
	}
}

func TestParseRejectsWrongIssuerAndAudience(t *testing.T) {
	token, _, err := newTM(time.Hour).IssueUser(1, "0100", 1, RoleFarmer)
	if err != nil {
		t.Fatalf("IssueUser: %v", err)
	}
	for name, tm := range map[string]*TokenManager{
		"issuer":   NewTokenManager("test-signing-key", "other", "raai-app", time.Hour),
		"audience": NewTokenManager("test-signing-key", "raai", "other-app", time.Hour),
	} {
		if _, err := tm.Parse(token); err == nil {
			t.Errorf("Parse accepted a token with a mismatched %s", name)
		}
	}
}

func TestParseRejectsExpiredToken(t *testing.T) {
	tm := newTM(-time.Minute) // already expired when issued
	token, _, err := tm.IssueUser(1, "0100", 1, RoleFarmer)
	if err != nil {
		t.Fatalf("IssueUser: %v", err)
	}
	if _, err := tm.Parse(token); err == nil {
		t.Fatal("Parse accepted an expired token")
	}
}

// The "alg: none" downgrade is the classic JWT attack; the parser pins HMAC.
func TestParseRejectsNoneAlgorithm(t *testing.T) {
	const unsigned = "eyJhbGciOiJub25lIiwidHlwIjoiSldUIn0." +
		"eyJzdWIiOiIxIiwiaXNzIjoicmFhaSIsImF1ZCI6WyJyYWFpLWFwcCJdfQ."
	if _, err := newTM(time.Hour).Parse(unsigned); err == nil {
		t.Fatal("Parse accepted an unsigned token")
	}
}

func TestNewRefreshTokenIsRandom(t *testing.T) {
	seen := make(map[string]bool, 100)
	for i := 0; i < 100; i++ {
		tok := NewRefreshToken()
		if len(tok) != 64 { // 32 random bytes, hex-encoded
			t.Fatalf("token length = %d, want 64", len(tok))
		}
		if seen[tok] {
			t.Fatal("NewRefreshToken returned a duplicate")
		}
		seen[tok] = true
	}
}
