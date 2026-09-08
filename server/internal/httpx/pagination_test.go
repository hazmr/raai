package httpx

import (
	"net/http"
	"net/http/httptest"
	"testing"
	"time"
)

func parsePageFor(t *testing.T, query string) (Page, error) {
	t.Helper()
	return ParsePage(httptest.NewRequest(http.MethodGet, "/animals?"+query, nil))
}

func TestParsePageDefaults(t *testing.T) {
	p, err := parsePageFor(t, "")
	if err != nil {
		t.Fatalf("ParsePage: %v", err)
	}
	if p.Limit != defaultLimit {
		t.Errorf("Limit = %d, want %d", p.Limit, defaultLimit)
	}
	// With no cursor the pgtype value must be invalid so SQL takes the first-page branch.
	if p.CursorTime().Valid {
		t.Error("CursorTime().Valid = true with no cursor")
	}
	if p.CursorID() != 0 {
		t.Errorf("CursorID() = %d, want 0", p.CursorID())
	}
}

func TestParsePageClampsLimit(t *testing.T) {
	p, err := parsePageFor(t, "limit=5000")
	if err != nil {
		t.Fatalf("ParsePage: %v", err)
	}
	if p.Limit != maxLimit {
		t.Errorf("Limit = %d, want the %d cap", p.Limit, maxLimit)
	}
}

func TestParsePageRejectsBadLimit(t *testing.T) {
	for _, q := range []string{"limit=0", "limit=-3", "limit=many"} {
		_, err := parsePageFor(t, q)
		apiErr, ok := err.(*APIError)
		if !ok {
			t.Fatalf("%s: error = %v, want *APIError", q, err)
		}
		if apiErr.Status != http.StatusBadRequest {
			t.Errorf("%s: status = %d, want 400", q, apiErr.Status)
		}
	}
}

func TestCursorRoundTrip(t *testing.T) {
	// Nanosecond precision must survive: the cursor is a (created_at, id) keyset.
	want := time.Date(2026, 3, 14, 15, 9, 26, 535897932, time.UTC)
	cursor := EncodeCursor(want, 4242)

	p, err := parsePageFor(t, "cursor="+cursor)
	if err != nil {
		t.Fatalf("ParsePage: %v", err)
	}
	ct := p.CursorTime()
	if !ct.Valid {
		t.Fatal("CursorTime().Valid = false for a supplied cursor")
	}
	if !ct.Time.Equal(want) {
		t.Errorf("cursor time = %v, want %v", ct.Time, want)
	}
	if p.CursorID() != 4242 {
		t.Errorf("CursorID() = %d, want 4242", p.CursorID())
	}
}

func TestEncodeCursorNormalizesToUTC(t *testing.T) {
	cairo := time.FixedZone("EET", 2*60*60)
	instant := time.Date(2026, 1, 1, 12, 0, 0, 0, cairo)

	p, err := parsePageFor(t, "cursor="+EncodeCursor(instant, 1))
	if err != nil {
		t.Fatalf("ParsePage: %v", err)
	}
	if !p.CursorTime().Time.Equal(instant) {
		t.Errorf("cursor time = %v, want the same instant as %v", p.CursorTime().Time, instant)
	}
}

func TestParsePageRejectsMalformedCursor(t *testing.T) {
	for name, q := range map[string]string{
		"not base64":    "cursor=!!!not-base64!!!",
		"missing pipe":  "cursor=" + b64("2026-01-01T00:00:00Z"),
		"bad timestamp": "cursor=" + b64("not-a-time|7"),
		"bad id":        "cursor=" + b64("2026-01-01T00:00:00Z|not-an-id"),
	} {
		_, err := parsePageFor(t, q)
		apiErr, ok := err.(*APIError)
		if !ok {
			t.Fatalf("%s: error = %v, want *APIError", name, err)
		}
		if apiErr.Status != http.StatusBadRequest {
			t.Errorf("%s: status = %d, want 400", name, apiErr.Status)
		}
	}
}
