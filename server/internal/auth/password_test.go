package auth

import "testing"

func TestHashPasswordVerifies(t *testing.T) {
	hash, err := HashPassword("correct horse")
	if err != nil {
		t.Fatalf("HashPassword: %v", err)
	}
	if hash == "correct horse" {
		t.Fatal("password was stored in plaintext")
	}
	if !CheckPassword(hash, "correct horse") {
		t.Error("CheckPassword rejected the correct password")
	}
	if CheckPassword(hash, "wrong horse") {
		t.Error("CheckPassword accepted the wrong password")
	}
}

func TestHashPasswordIsSalted(t *testing.T) {
	first, err := HashPassword("same-password")
	if err != nil {
		t.Fatalf("HashPassword: %v", err)
	}
	second, err := HashPassword("same-password")
	if err != nil {
		t.Fatalf("HashPassword: %v", err)
	}
	if first == second {
		t.Fatal("two hashes of the same password are identical — missing salt")
	}
}

func TestCheckPasswordRejectsGarbageHash(t *testing.T) {
	if CheckPassword("not-a-bcrypt-hash", "anything") {
		t.Error("CheckPassword accepted a malformed hash")
	}
}
