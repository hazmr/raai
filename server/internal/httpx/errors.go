// Package httpx holds the shared HTTP plumbing every domain reuses: the single
// error envelope (§6.6), JSON encode/decode, and cursor pagination (§6.1).
package httpx

import (
	"encoding/json"
	"log/slog"
	"net/http"
)

// APIError is a typed error carrying the HTTP status, the machine-readable
// snake_case code, and a human message. It satisfies error so handlers/services
// can `return` it and let WriteError render the envelope.
type APIError struct {
	Status  int               `json:"-"`
	Code    string            `json:"code"`
	Message string            `json:"message"`
	Fields  map[string]string `json:"fields,omitempty"`
}

func (e *APIError) Error() string { return e.Code + ": " + e.Message }

// Constructors for the codes in §6.6.
func ErrBadRequest(msg string) *APIError {
	return &APIError{http.StatusBadRequest, "bad_request", msg, nil}
}
func ErrUnauthorized(msg string) *APIError {
	return &APIError{http.StatusUnauthorized, "unauthorized", msg, nil}
}
func ErrSubscriptionRequired(msg string) *APIError {
	return &APIError{http.StatusPaymentRequired, "subscription_required", msg, nil}
}
func ErrForbidden(msg string) *APIError {
	return &APIError{http.StatusForbidden, "forbidden", msg, nil}
}
func ErrNotFound(msg string) *APIError { return &APIError{http.StatusNotFound, "not_found", msg, nil} }
func ErrConflict(msg string) *APIError { return &APIError{http.StatusConflict, "conflict", msg, nil} }
func ErrRateLimited(msg string) *APIError {
	return &APIError{http.StatusTooManyRequests, "rate_limited", msg, nil}
}
func ErrInternal() *APIError {
	return &APIError{http.StatusInternalServerError, "internal_error", "something went wrong", nil}
}

// ErrValidation builds a 422 with optional per-field messages.
func ErrValidation(msg string, fields map[string]string) *APIError {
	return &APIError{http.StatusUnprocessableEntity, "validation_error", msg, fields}
}

type errorEnvelope struct {
	Error *APIError `json:"error"`
}

// WriteError renders any error as the standard envelope. Non-APIErrors are
// treated as 500 and the detail is logged, never leaked to the client.
func WriteError(w http.ResponseWriter, r *http.Request, err error) {
	apiErr, ok := err.(*APIError)
	if !ok {
		slog.ErrorContext(r.Context(), "unhandled error", "err", err, "path", r.URL.Path)
		apiErr = ErrInternal()
	}
	if apiErr.Status >= 500 {
		slog.ErrorContext(r.Context(), "server error", "err", err, "path", r.URL.Path)
	}
	writeJSON(w, apiErr.Status, errorEnvelope{Error: apiErr})
}

// WriteJSON writes a value as JSON with the given status.
func WriteJSON(w http.ResponseWriter, status int, v any) {
	writeJSON(w, status, v)
}

func writeJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(status)
	if v != nil {
		_ = json.NewEncoder(w).Encode(v)
	}
}

// NoContent writes a 204.
func NoContent(w http.ResponseWriter) { w.WriteHeader(http.StatusNoContent) }
