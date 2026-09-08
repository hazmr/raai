package server_test

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strings"
	"testing"

	"raai/internal/testutil"
)

// doWithKey sends a POST carrying an Idempotency-Key, the way the app's outbox
// replays a queued write.
func doWithKey(t *testing.T, env *testutil.Env, path, token, key string, body any) (int, []byte, http.Header) {
	t.Helper()

	raw, err := json.Marshal(body)
	if err != nil {
		t.Fatalf("marshal: %v", err)
	}
	req, err := http.NewRequest(http.MethodPost, env.Server.URL+path, bytes.NewReader(raw))
	if err != nil {
		t.Fatalf("build request: %v", err)
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+token)
	req.Header.Set("Idempotency-Key", key)

	resp, err := env.Client.Do(req)
	if err != nil {
		t.Fatalf("POST %s: %v", path, err)
	}
	defer resp.Body.Close()
	out, err := io.ReadAll(resp.Body)
	if err != nil {
		t.Fatalf("read body: %v", err)
	}
	return resp.StatusCode, out, resp.Header
}

func countNotes(t *testing.T, env *testutil.Env, animalID int32) int {
	t.Helper()
	var n int
	if err := env.Pool.QueryRow(t.Context(),
		`SELECT count(*) FROM animal_notes WHERE animal_id = $1`, animalID).Scan(&n); err != nil {
		t.Fatalf("count notes: %v", err)
	}
	return n
}

// The outbox replays a queued note after the signal returns; the farmer must end
// up with one note, not two.
func TestReplayedNoteCreatesOneRow(t *testing.T) {
	env := testutil.New(t)
	admin := env.Register("01700000001", "secret123", "Farm")
	env.Activate(admin.FarmID)
	animalID := env.CreateAnimal(admin.Access, "TAG-IDEM")
	path := fmt.Sprintf("/api/v1/animals/%d/notes", animalID)
	body := map[string]string{"body": "أعطيت المضاد الحيوي"}

	status, first, _ := doWithKey(t, env, path, admin.Access, "outbox-note-1", body)
	if status != http.StatusCreated {
		t.Fatalf("first status = %d, want 201 (%s)", status, first)
	}

	status, second, headers := doWithKey(t, env, path, admin.Access, "outbox-note-1", body)
	if status != http.StatusCreated {
		t.Fatalf("replay status = %d, want the stored 201 (%s)", status, second)
	}
	if headers.Get("Idempotent-Replay") != "true" {
		t.Error("replay is not marked with the Idempotent-Replay header")
	}
	if !bytes.Equal(first, second) {
		t.Errorf("replay body differs:\n first: %s\nsecond: %s", first, second)
	}
	if n := countNotes(t, env, animalID); n != 1 {
		t.Errorf("%d notes stored, want 1", n)
	}
}

// Without a key the same POST legitimately creates a second note.
func TestRepeatedNoteWithoutKeyCreatesTwoRows(t *testing.T) {
	env := testutil.New(t)
	admin := env.Register("01700000002", "secret123", "Farm")
	env.Activate(admin.FarmID)
	animalID := env.CreateAnimal(admin.Access, "TAG-NOKEY")

	createNote(t, env, admin.Access, animalID, "same text")
	createNote(t, env, admin.Access, animalID, "same text")

	if n := countNotes(t, env, animalID); n != 2 {
		t.Errorf("%d notes stored, want 2", n)
	}
}

func TestDistinctKeysCreateDistinctNotes(t *testing.T) {
	env := testutil.New(t)
	admin := env.Register("01700000003", "secret123", "Farm")
	env.Activate(admin.FarmID)
	animalID := env.CreateAnimal(admin.Access, "TAG-TWOKEYS")
	path := fmt.Sprintf("/api/v1/animals/%d/notes", animalID)

	doWithKey(t, env, path, admin.Access, "key-a", map[string]string{"body": "first"})
	doWithKey(t, env, path, admin.Access, "key-b", map[string]string{"body": "second"})

	if n := countNotes(t, env, animalID); n != 2 {
		t.Errorf("%d notes stored, want 2", n)
	}
}

// Reusing one key for a different payload is a client bug — it must be reported,
// not silently answered with the earlier response.
func TestReusingKeyForDifferentBodyConflicts(t *testing.T) {
	env := testutil.New(t)
	admin := env.Register("01700000004", "secret123", "Farm")
	env.Activate(admin.FarmID)
	animalID := env.CreateAnimal(admin.Access, "TAG-MISMATCH")
	path := fmt.Sprintf("/api/v1/animals/%d/notes", animalID)

	doWithKey(t, env, path, admin.Access, "shared-key", map[string]string{"body": "original"})
	status, out, _ := doWithKey(t, env, path, admin.Access, "shared-key", map[string]string{"body": "different"})

	if status != http.StatusConflict {
		t.Fatalf("status = %d, want 409 (%s)", status, out)
	}
	if n := countNotes(t, env, animalID); n != 1 {
		t.Errorf("%d notes stored, want 1", n)
	}
}

// Re-registering a scanned ear tag from the outbox must replay the original
// animal, not fail with the duplicate-barcode conflict.
func TestReplayedAnimalReturnsTheSameAnimal(t *testing.T) {
	env := testutil.New(t)
	admin := env.Register("01700000005", "secret123", "Farm")
	env.Activate(admin.FarmID)
	body := map[string]string{"barcode": "TAG-REPLAY"}

	status, first, _ := doWithKey(t, env, "/api/v1/animals", admin.Access, "outbox-animal-1", body)
	if status != http.StatusCreated {
		t.Fatalf("first status = %d, want 201 (%s)", status, first)
	}
	status, second, _ := doWithKey(t, env, "/api/v1/animals", admin.Access, "outbox-animal-1", body)
	if status != http.StatusCreated {
		t.Fatalf("replay status = %d, want 201 (%s)", status, second)
	}
	if !bytes.Equal(first, second) {
		t.Errorf("replay returned a different animal:\n%s\n%s", first, second)
	}

	var count int
	if err := env.Pool.QueryRow(t.Context(),
		`SELECT count(*) FROM animals WHERE farm_id = $1`, admin.FarmID).Scan(&count); err != nil {
		t.Fatalf("count animals: %v", err)
	}
	if count != 1 {
		t.Errorf("%d animals stored, want 1", count)
	}
}

// A failed attempt must not burn the key: the farmer pays, the outbox retries the
// very same request, and it has to go through.
func TestFailedRequestReleasesTheKey(t *testing.T) {
	env := testutil.New(t)
	admin := env.Register("01700000006", "secret123", "Farm")
	body := map[string]string{"barcode": "TAG-AFTER-PAYING"}

	status, out, _ := doWithKey(t, env, "/api/v1/animals", admin.Access, "retry-key", body)
	if status != http.StatusPaymentRequired {
		t.Fatalf("status = %d, want 402 (%s)", status, out)
	}

	env.Activate(admin.FarmID)

	status, out, _ = doWithKey(t, env, "/api/v1/animals", admin.Access, "retry-key", body)
	if status != http.StatusCreated {
		t.Fatalf("retry after paying = %d, want 201 (%s)", status, out)
	}
}

func TestValidationFailureReleasesTheKey(t *testing.T) {
	env := testutil.New(t)
	admin := env.Register("01700000007", "secret123", "Farm")
	env.Activate(admin.FarmID)
	animalID := env.CreateAnimal(admin.Access, "TAG-FIXTYPO")
	path := fmt.Sprintf("/api/v1/animals/%d/notes", animalID)

	status, _, _ := doWithKey(t, env, path, admin.Access, "typo-key", map[string]string{"body": "  "})
	if status != http.StatusUnprocessableEntity {
		t.Fatalf("status = %d, want 422", status)
	}
	status, out, _ := doWithKey(t, env, path, admin.Access, "typo-key", map[string]string{"body": "corrected"})
	if status != http.StatusCreated {
		t.Fatalf("corrected retry = %d, want 201 (%s)", status, out)
	}
}

// Keys are scoped per farm, so two farms can't collide on one uuid.
func TestKeysAreScopedPerFarm(t *testing.T) {
	env := testutil.New(t)
	one := env.Register("01700000008", "secret123", "Farm One")
	two := env.Register("01700000009", "secret123", "Farm Two")
	env.Activate(one.FarmID)
	env.Activate(two.FarmID)

	body := map[string]string{"barcode": "TAG-SHARED-KEY"}
	if status, out, _ := doWithKey(t, env, "/api/v1/animals", one.Access, "same-uuid", body); status != http.StatusCreated {
		t.Fatalf("farm one status = %d (%s)", status, out)
	}
	if status, out, _ := doWithKey(t, env, "/api/v1/animals", two.Access, "same-uuid", body); status != http.StatusCreated {
		t.Fatalf("farm two status = %d, want 201 — keys must not be global (%s)", status, out)
	}
}

// The paywall submit is where a double-tap matters most: two claims on one
// InstaPay transfer would sit in the admin's review queue as duplicates.
func TestReplayedPaymentSubmit(t *testing.T) {
	env := testutil.New(t)
	admin := env.Register("01700000010", "secret123", "Farm")
	body := map[string]any{"plan": "monthly", "instapayRef": "IDEM-PAY-1", "amountEgp": 150}

	status, first, _ := doWithKey(t, env, "/api/v1/billing/payments", admin.Access, "pay-key", body)
	if status != http.StatusCreated {
		t.Fatalf("first status = %d, want 201 (%s)", status, first)
	}
	status, second, _ := doWithKey(t, env, "/api/v1/billing/payments", admin.Access, "pay-key", body)
	if status != http.StatusCreated || !bytes.Equal(first, second) {
		t.Fatalf("replay status = %d body = %s, want the stored 201 %s", status, second, first)
	}

	var count int
	if err := env.Pool.QueryRow(t.Context(),
		`SELECT count(*) FROM payments WHERE farm_id = $1`, admin.FarmID).Scan(&count); err != nil {
		t.Fatalf("count payments: %v", err)
	}
	if count != 1 {
		t.Errorf("%d payments stored, want 1", count)
	}
}

func TestOverlongKeyIsRejected(t *testing.T) {
	env := testutil.New(t)
	admin := env.Register("01700000011", "secret123", "Farm")
	env.Activate(admin.FarmID)

	status, _, _ := doWithKey(t, env, "/api/v1/animals", admin.Access, strings.Repeat("k", 201),
		map[string]string{"barcode": "TAG-LONGKEY"})
	if status != http.StatusBadRequest {
		t.Errorf("status = %d, want 400", status)
	}
}

// Purging past the replay window frees the key for reuse.
func TestPurgeDropsExpiredKeys(t *testing.T) {
	env := testutil.New(t)
	admin := env.Register("01700000012", "secret123", "Farm")
	env.Activate(admin.FarmID)

	doWithKey(t, env, "/api/v1/animals", admin.Access, "old-key", map[string]string{"barcode": "TAG-OLD-KEY"})

	if _, err := env.Pool.Exec(t.Context(),
		`UPDATE idempotency_keys SET created_at = now() - interval '48 hours'`); err != nil {
		t.Fatalf("age the key: %v", err)
	}
	tag, err := env.Pool.Exec(t.Context(),
		`DELETE FROM idempotency_keys WHERE created_at < now() - make_interval(hours => 24)`)
	if err != nil {
		t.Fatalf("purge: %v", err)
	}
	if tag.RowsAffected() != 1 {
		t.Errorf("purged %d keys, want 1", tag.RowsAffected())
	}
}
