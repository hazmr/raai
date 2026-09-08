package httpx

import (
	"encoding/base64"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"testing"
)

func b64(s string) string { return base64.RawURLEncoding.EncodeToString([]byte(s)) }

func writeErrFor(t *testing.T, err error) (int, map[string]any) {
	t.Helper()
	rec := httptest.NewRecorder()
	WriteError(rec, httptest.NewRequest(http.MethodGet, "/x", nil), err)

	var env struct {
		Error map[string]any `json:"error"`
	}
	if jsonErr := json.Unmarshal(rec.Body.Bytes(), &env); jsonErr != nil {
		t.Fatalf("decode envelope %q: %v", rec.Body.String(), jsonErr)
	}
	return rec.Code, env.Error
}

func TestWriteErrorRendersEnvelope(t *testing.T) {
	cases := map[string]struct {
		err        *APIError
		wantStatus int
		wantCode   string
	}{
		"bad request":  {ErrBadRequest("nope"), http.StatusBadRequest, "bad_request"},
		"unauthorized": {ErrUnauthorized("nope"), http.StatusUnauthorized, "unauthorized"},
		"paywall":      {ErrSubscriptionRequired("pay"), http.StatusPaymentRequired, "subscription_required"},
		"forbidden":    {ErrForbidden("nope"), http.StatusForbidden, "forbidden"},
		"not found":    {ErrNotFound("nope"), http.StatusNotFound, "not_found"},
		"conflict":     {ErrConflict("dupe"), http.StatusConflict, "conflict"},
		"rate limited": {ErrRateLimited("slow"), http.StatusTooManyRequests, "rate_limited"},
	}
	for name, tc := range cases {
		status, env := writeErrFor(t, tc.err)
		if status != tc.wantStatus {
			t.Errorf("%s: status = %d, want %d", name, status, tc.wantStatus)
		}
		if env["code"] != tc.wantCode {
			t.Errorf("%s: code = %v, want %q", name, env["code"], tc.wantCode)
		}
	}
}

func TestWriteErrorValidationCarriesFields(t *testing.T) {
	status, env := writeErrFor(t, ErrValidation("invalid", map[string]string{"plan": "is required"}))
	if status != http.StatusUnprocessableEntity {
		t.Errorf("status = %d, want 422", status)
	}
	fields, ok := env["fields"].(map[string]any)
	if !ok {
		t.Fatalf("fields = %v, want an object", env["fields"])
	}
	if fields["plan"] != "is required" {
		t.Errorf("fields[plan] = %v, want %q", fields["plan"], "is required")
	}
}

// An unexpected error must become a generic 500 — never leak internals (e.g. a DSN).
func TestWriteErrorHidesUnexpectedErrors(t *testing.T) {
	status, env := writeErrFor(t, errors.New("pq: password authentication failed for user \"raai\""))
	if status != http.StatusInternalServerError {
		t.Errorf("status = %d, want 500", status)
	}
	if env["code"] != "internal_error" {
		t.Errorf("code = %v, want internal_error", env["code"])
	}
	if msg, _ := env["message"].(string); msg != "something went wrong" {
		t.Errorf("message = %q, want the generic message", msg)
	}
}

func TestErrorsOmitEmptyFields(t *testing.T) {
	_, env := writeErrFor(t, ErrNotFound("animal not found"))
	if _, present := env["fields"]; present {
		t.Error("fields present on an error that has none")
	}
}

func TestNoContentWritesNoBody(t *testing.T) {
	rec := httptest.NewRecorder()
	NoContent(rec)
	if rec.Code != http.StatusNoContent {
		t.Errorf("status = %d, want 204", rec.Code)
	}
	if rec.Body.Len() != 0 {
		t.Errorf("body = %q, want empty", rec.Body.String())
	}
}
