package httpx

import (
	"encoding/base64"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/jackc/pgx/v5/pgtype"
)

const (
	defaultLimit = 50
	maxLimit     = 200
)

// Page holds parsed pagination params: a row limit and an optional decoded cursor
// pointing at the last item of the previous page (§6.1).
type Page struct {
	Limit      int32
	hasCursor  bool
	cursorTime time.Time
	cursorID   int32
}

// List is the wrapper every collection response uses: {data, nextCursor}.
type List[T any] struct {
	Data       []T     `json:"data"`
	NextCursor *string `json:"nextCursor"`
}

// ParsePage reads ?limit= and ?cursor= from the query string.
func ParsePage(r *http.Request) (Page, error) {
	p := Page{Limit: defaultLimit}
	if raw := r.URL.Query().Get("limit"); raw != "" {
		n, err := strconv.Atoi(raw)
		if err != nil || n <= 0 {
			return p, ErrBadRequest("limit must be a positive integer")
		}
		if n > maxLimit {
			n = maxLimit
		}
		p.Limit = int32(n)
	}
	if raw := r.URL.Query().Get("cursor"); raw != "" {
		t, id, err := decodeCursor(raw)
		if err != nil {
			return p, ErrBadRequest("invalid cursor")
		}
		p.hasCursor, p.cursorTime, p.cursorID = true, t, id
	}
	return p, nil
}

// CursorTime returns the cursor timestamp as a pgtype value (Valid=false when
// there is no cursor, so the SQL `narg IS NULL` branch selects the first page).
func (p Page) CursorTime() pgtype.Timestamptz {
	return pgtype.Timestamptz{Time: p.cursorTime, Valid: p.hasCursor}
}

func (p Page) CursorID() int32 { return p.cursorID }

// EncodeCursor builds the opaque cursor for the last row of a page.
func EncodeCursor(t time.Time, id int32) string {
	raw := t.UTC().Format(time.RFC3339Nano) + "|" + strconv.FormatInt(int64(id), 10)
	return base64.RawURLEncoding.EncodeToString([]byte(raw))
}

func decodeCursor(s string) (time.Time, int32, error) {
	b, err := base64.RawURLEncoding.DecodeString(s)
	if err != nil {
		return time.Time{}, 0, err
	}
	parts := strings.SplitN(string(b), "|", 2)
	if len(parts) != 2 {
		return time.Time{}, 0, strconv.ErrSyntax
	}
	t, err := time.Parse(time.RFC3339Nano, parts[0])
	if err != nil {
		return time.Time{}, 0, err
	}
	id, err := strconv.ParseInt(parts[1], 10, 32)
	if err != nil {
		return time.Time{}, 0, err
	}
	return t, int32(id), nil
}
