package httpx

import (
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"strconv"

	"github.com/go-chi/chi/v5"
)

// DecodeJSON strictly decodes a JSON request body into dst, mapping any failure
// to a 400 bad_request so malformed bodies never reach handler logic.
func DecodeJSON(r *http.Request, dst any) error {
	dec := json.NewDecoder(io.LimitReader(r.Body, 1<<20)) // 1 MiB cap
	dec.DisallowUnknownFields()
	if err := dec.Decode(dst); err != nil {
		if errors.Is(err, io.EOF) {
			return ErrBadRequest("request body is required")
		}
		return ErrBadRequest("malformed JSON body")
	}
	return nil
}

// PathInt reads an integer URL parameter (e.g. {id}); a non-numeric value is a 404
// since such a resource cannot exist.
func PathInt(r *http.Request, key string) (int32, error) {
	raw := chi.URLParam(r, key)
	n, err := strconv.ParseInt(raw, 10, 32)
	if err != nil {
		return 0, ErrNotFound("resource not found")
	}
	return int32(n), nil
}
