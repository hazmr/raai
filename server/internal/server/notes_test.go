package server_test

import (
	"fmt"
	"net/http"
	"testing"

	"raai/internal/testutil"
)

type noteDTO struct {
	ID          int32  `json:"id"`
	AnimalID    int32  `json:"animalId"`
	Body        string `json:"body"`
	AuthorKind  string `json:"authorKind"`
	AuthorLabel string `json:"authorLabel"`
	InviteID    *int32 `json:"inviteId"`
}

func createNote(t *testing.T, env *testutil.Env, token string, animalID int32, body string) noteDTO {
	t.Helper()
	var n noteDTO
	env.Do(http.MethodPost, fmt.Sprintf("/api/v1/animals/%d/notes", animalID), token,
		map[string]string{"body": body}).ExpectStatus(http.StatusCreated).JSON(&n)
	return n
}

// addMember creates a second farmer in the same farm and logs them in.
func addMember(t *testing.T, env *testutil.Env, adminToken, phone string) string {
	t.Helper()
	env.Do(http.MethodPost, "/api/v1/farm/members", adminToken, map[string]string{
		"phoneNumber": phone,
		"password":    "secret123",
	}).ExpectStatus(http.StatusCreated)

	var tokens struct {
		AccessToken string `json:"accessToken"`
	}
	env.Do(http.MethodPost, "/api/v1/auth/login", "", map[string]string{
		"phoneNumber": phone,
		"password":    "secret123",
	}).ExpectStatus(http.StatusOK).JSON(&tokens)
	return tokens.AccessToken
}

func TestMemberNoteRecordsAuthorship(t *testing.T) {
	env := testutil.New(t)
	admin := env.Register("01500000001", "secret123", "Farm")
	env.Activate(admin.FarmID)
	animalID := env.CreateAnimal(admin.Access, "TAG-NOTE")

	note := createNote(t, env, admin.Access, animalID, "أكلت جيداً اليوم")
	if note.AuthorKind != "member" {
		t.Errorf("authorKind = %q, want member", note.AuthorKind)
	}
	if note.AuthorLabel != "01500000001" {
		t.Errorf("authorLabel = %q, want the member's phone", note.AuthorLabel)
	}
	if note.InviteID != nil {
		t.Errorf("inviteId = %v, want nil for a member's note", note.InviteID)
	}
	if note.Body != "أكلت جيداً اليوم" {
		t.Errorf("body = %q, want the Arabic text unchanged", note.Body)
	}
}

// Notes are the animal's record: only their author may rewrite history.
func TestOnlyTheAuthorCanEditOrDeleteANote(t *testing.T) {
	env := testutil.New(t)
	admin := env.Register("01500000002", "secret123", "Farm")
	env.Activate(admin.FarmID)
	animalID := env.CreateAnimal(admin.Access, "TAG-AUTHOR")
	other := addMember(t, env, admin.Access, "01500000003")

	note := createNote(t, env, admin.Access, animalID, "original")
	path := fmt.Sprintf("/api/v1/animals/%d/notes/%d", animalID, note.ID)

	// A farm-mate can read it but not change it.
	env.Do(http.MethodGet, path, other, nil).ExpectStatus(http.StatusOK)
	env.Do(http.MethodPatch, path, other, map[string]string{"body": "tampered"}).
		ExpectStatus(http.StatusNotFound)
	env.Do(http.MethodDelete, path, other, nil).ExpectStatus(http.StatusNotFound)

	var unchanged noteDTO
	env.Do(http.MethodGet, path, admin.Access, nil).ExpectStatus(http.StatusOK).JSON(&unchanged)
	if unchanged.Body != "original" {
		t.Errorf("body = %q, want it untouched", unchanged.Body)
	}

	// The author can.
	var edited noteDTO
	env.Do(http.MethodPatch, path, admin.Access, map[string]string{"body": "corrected"}).
		ExpectStatus(http.StatusOK).JSON(&edited)
	if edited.Body != "corrected" {
		t.Errorf("body = %q, want corrected", edited.Body)
	}
	env.Do(http.MethodDelete, path, admin.Access, nil).ExpectStatus(http.StatusNoContent)
	env.Do(http.MethodGet, path, admin.Access, nil).ExpectStatus(http.StatusNotFound)
}

// A doctor must not be able to edit the farmer's notes, nor the reverse.
func TestDoctorAndMemberCannotEditEachOthersNotes(t *testing.T) {
	env := testutil.New(t)
	admin := env.Register("01500000004", "secret123", "Farm")
	env.Activate(admin.FarmID)
	animalID := env.CreateAnimal(admin.Access, "TAG-CROSS")
	sess := redeem(t, env, createInvite(t, env, admin.Access, "Dr Cross").Token)

	memberNote := createNote(t, env, admin.Access, animalID, "farmer's note")
	doctorNote := createNote(t, env, sess.AccessToken, animalID, "vet's note")

	env.Do(http.MethodPatch, fmt.Sprintf("/api/v1/animals/%d/notes/%d", animalID, memberNote.ID),
		sess.AccessToken, map[string]string{"body": "vet edit"}).ExpectStatus(http.StatusNotFound)

	env.Do(http.MethodPatch, fmt.Sprintf("/api/v1/animals/%d/notes/%d", animalID, doctorNote.ID),
		admin.Access, map[string]string{"body": "farmer edit"}).ExpectStatus(http.StatusNotFound)

	// Each may edit their own.
	env.Do(http.MethodPatch, fmt.Sprintf("/api/v1/animals/%d/notes/%d", animalID, doctorNote.ID),
		sess.AccessToken, map[string]string{"body": "vet correction"}).ExpectStatus(http.StatusOK)
}

func TestNoteBodyIsRequired(t *testing.T) {
	env := testutil.New(t)
	admin := env.Register("01500000005", "secret123", "Farm")
	env.Activate(admin.FarmID)
	animalID := env.CreateAnimal(admin.Access, "TAG-EMPTY")

	for _, body := range []string{"", "   "} {
		resp := env.Do(http.MethodPost, fmt.Sprintf("/api/v1/animals/%d/notes", animalID),
			admin.Access, map[string]string{"body": body}).
			ExpectStatus(http.StatusUnprocessableEntity)
		if code := resp.ErrorCode(); code != "validation_error" {
			t.Errorf("code = %q, want validation_error", code)
		}
	}
}

func TestNotesOnUnknownAnimalAre404(t *testing.T) {
	env := testutil.New(t)
	admin := env.Register("01500000006", "secret123", "Farm")
	env.Activate(admin.FarmID)

	env.Do(http.MethodGet, "/api/v1/animals/999999/notes", admin.Access, nil).
		ExpectStatus(http.StatusNotFound)
	env.Do(http.MethodPost, "/api/v1/animals/999999/notes", admin.Access,
		map[string]string{"body": "orphan"}).ExpectStatus(http.StatusNotFound)
}

func TestAnimalNoteCountAndEmbeddedNotes(t *testing.T) {
	env := testutil.New(t)
	admin := env.Register("01500000007", "secret123", "Farm")
	env.Activate(admin.FarmID)
	animalID := env.CreateAnimal(admin.Access, "TAG-COUNT")

	createNote(t, env, admin.Access, animalID, "first")
	createNote(t, env, admin.Access, animalID, "second")

	var withNotes struct {
		NoteCount int64     `json:"noteCount"`
		Notes     []noteDTO `json:"notes"`
	}
	env.Do(http.MethodGet, fmt.Sprintf("/api/v1/animals/%d?include=notes", animalID), admin.Access, nil).
		ExpectStatus(http.StatusOK).JSON(&withNotes)

	if withNotes.NoteCount != 2 {
		t.Errorf("noteCount = %d, want 2", withNotes.NoteCount)
	}
	if len(withNotes.Notes) != 2 {
		t.Errorf("embedded notes = %d, want 2", len(withNotes.Notes))
	}

	// Without ?include=notes the payload stays lean.
	var lean struct {
		NoteCount int64     `json:"noteCount"`
		Notes     []noteDTO `json:"notes"`
	}
	env.Do(http.MethodGet, fmt.Sprintf("/api/v1/animals/%d", animalID), admin.Access, nil).
		ExpectStatus(http.StatusOK).JSON(&lean)
	if lean.NoteCount != 2 {
		t.Errorf("noteCount = %d, want 2", lean.NoteCount)
	}
	if len(lean.Notes) != 0 {
		t.Errorf("notes embedded without ?include=notes: %d", len(lean.Notes))
	}
}

func TestNotesPaginateNewestFirst(t *testing.T) {
	env := testutil.New(t)
	admin := env.Register("01500000008", "secret123", "Farm")
	env.Activate(admin.FarmID)
	animalID := env.CreateAnimal(admin.Access, "TAG-PAGES")

	for i := range 5 {
		createNote(t, env, admin.Access, animalID, fmt.Sprintf("note %d", i))
	}

	type page struct {
		Data       []noteDTO `json:"data"`
		NextCursor *string   `json:"nextCursor"`
	}
	var first page
	env.Do(http.MethodGet, fmt.Sprintf("/api/v1/animals/%d/notes?limit=2", animalID), admin.Access, nil).
		ExpectStatus(http.StatusOK).JSON(&first)

	if len(first.Data) != 2 {
		t.Fatalf("first page has %d notes, want 2", len(first.Data))
	}
	if first.Data[0].Body != "note 4" {
		t.Errorf("newest note = %q, want %q", first.Data[0].Body, "note 4")
	}
	if first.NextCursor == nil {
		t.Fatal("first page has no nextCursor")
	}

	var second page
	env.Do(http.MethodGet, fmt.Sprintf("/api/v1/animals/%d/notes?limit=2&cursor=%s", animalID, *first.NextCursor),
		admin.Access, nil).ExpectStatus(http.StatusOK).JSON(&second)
	if len(second.Data) != 2 || second.Data[0].Body != "note 2" {
		t.Errorf("second page = %+v, want notes 2 and 1", second.Data)
	}
}

// Deleting an animal takes its notes with it (ON DELETE CASCADE).
func TestDeletingAnimalRemovesItsNotes(t *testing.T) {
	env := testutil.New(t)
	admin := env.Register("01500000009", "secret123", "Farm")
	env.Activate(admin.FarmID)
	animalID := env.CreateAnimal(admin.Access, "TAG-CASCADE")
	createNote(t, env, admin.Access, animalID, "will be gone")

	env.Do(http.MethodDelete, fmt.Sprintf("/api/v1/animals/%d", animalID), admin.Access, nil).
		ExpectStatus(http.StatusNoContent)

	var remaining int
	if err := env.Pool.QueryRow(t.Context(),
		`SELECT count(*) FROM animal_notes WHERE animal_id = $1`, animalID).Scan(&remaining); err != nil {
		t.Fatalf("count notes: %v", err)
	}
	if remaining != 0 {
		t.Errorf("%d notes survived the animal", remaining)
	}
}

func TestMemberCanEditTheHerd(t *testing.T) {
	env := testutil.New(t)
	admin := env.Register("01500000010", "secret123", "Farm")
	env.Activate(admin.FarmID)
	animalID := env.CreateAnimal(admin.Access, "TAG-OLD")
	member := addMember(t, env, admin.Access, "01500000011")

	var updated struct {
		Barcode string `json:"barcode"`
	}
	env.Do(http.MethodPatch, fmt.Sprintf("/api/v1/animals/%d", animalID), member,
		map[string]string{"barcode": "TAG-NEW"}).ExpectStatus(http.StatusOK).JSON(&updated)
	if updated.Barcode != "TAG-NEW" {
		t.Errorf("barcode = %q, want TAG-NEW", updated.Barcode)
	}
}
