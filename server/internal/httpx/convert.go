package httpx

import (
	"time"

	"github.com/jackc/pgx/v5/pgtype"
)

// TimeOf renders a non-null timestamptz as a UTC time for JSON (RFC 3339, §6.1).
func TimeOf(ts pgtype.Timestamptz) time.Time { return ts.Time.UTC() }

// TimePtr renders a nullable timestamptz as *time.Time (null in JSON when unset).
func TimePtr(ts pgtype.Timestamptz) *time.Time {
	if !ts.Valid {
		return nil
	}
	t := ts.Time.UTC()
	return &t
}
