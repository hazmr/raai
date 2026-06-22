package db

import (
	"context"
	"fmt"
	"io/fs"
	"sort"
	"strconv"
	"strings"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"raai/migrations"
)

// migration is one versioned forward/backward pair derived from the embedded files.
type migration struct {
	version int64
	name    string
	up      string
	down    string
}

// loadMigrations parses the embedded migrations/*.sql files into ordered records.
// Filenames follow golang-migrate's convention: NNNN_name.up.sql / NNNN_name.down.sql.
func loadMigrations() ([]migration, error) {
	entries, err := fs.ReadDir(migrations.FS, ".")
	if err != nil {
		return nil, err
	}
	byVersion := map[int64]*migration{}
	for _, e := range entries {
		n := e.Name()
		if !strings.HasSuffix(n, ".sql") {
			continue
		}
		var direction string
		switch {
		case strings.HasSuffix(n, ".up.sql"):
			direction = "up"
		case strings.HasSuffix(n, ".down.sql"):
			direction = "down"
		default:
			continue
		}
		base := strings.SplitN(n, "_", 2)
		if len(base) != 2 {
			return nil, fmt.Errorf("bad migration filename %q", n)
		}
		ver, err := strconv.ParseInt(base[0], 10, 64)
		if err != nil {
			return nil, fmt.Errorf("bad migration version in %q: %w", n, err)
		}
		body, err := fs.ReadFile(migrations.FS, n)
		if err != nil {
			return nil, err
		}
		m := byVersion[ver]
		if m == nil {
			m = &migration{version: ver, name: strings.TrimSuffix(base[1], "."+direction+".sql")}
			byVersion[ver] = m
		}
		if direction == "up" {
			m.up = string(body)
		} else {
			m.down = string(body)
		}
	}

	out := make([]migration, 0, len(byVersion))
	for _, m := range byVersion {
		out = append(out, *m)
	}
	sort.Slice(out, func(i, j int) bool { return out[i].version < out[j].version })
	return out, nil
}

func ensureMigrationsTable(ctx context.Context, pool *pgxpool.Pool) error {
	_, err := pool.Exec(ctx, `
		CREATE TABLE IF NOT EXISTS schema_migrations (
			version    BIGINT PRIMARY KEY,
			applied_at TIMESTAMPTZ NOT NULL DEFAULT now()
		)`)
	return err
}

func appliedVersions(ctx context.Context, pool *pgxpool.Pool) (map[int64]bool, int64, error) {
	rows, err := pool.Query(ctx, `SELECT version FROM schema_migrations ORDER BY version`)
	if err != nil {
		return nil, 0, err
	}
	defer rows.Close()
	applied := map[int64]bool{}
	var max int64
	for rows.Next() {
		var v int64
		if err := rows.Scan(&v); err != nil {
			return nil, 0, err
		}
		applied[v] = true
		if v > max {
			max = v
		}
	}
	return applied, max, rows.Err()
}

// MigrateUp applies every not-yet-applied migration, each in its own transaction.
func MigrateUp(ctx context.Context, pool *pgxpool.Pool) (int, error) {
	if err := ensureMigrationsTable(ctx, pool); err != nil {
		return 0, err
	}
	migs, err := loadMigrations()
	if err != nil {
		return 0, err
	}
	applied, _, err := appliedVersions(ctx, pool)
	if err != nil {
		return 0, err
	}

	count := 0
	for _, m := range migs {
		if applied[m.version] {
			continue
		}
		if err := runInTx(ctx, pool, func(tx pgx.Tx) error {
			if _, err := tx.Exec(ctx, m.up); err != nil {
				return fmt.Errorf("migration %04d_%s up: %w", m.version, m.name, err)
			}
			_, err := tx.Exec(ctx, `INSERT INTO schema_migrations (version) VALUES ($1)`, m.version)
			return err
		}); err != nil {
			return count, err
		}
		count++
	}
	return count, nil
}

// MigrateDown rolls back the single most-recently-applied migration.
func MigrateDown(ctx context.Context, pool *pgxpool.Pool) (int64, error) {
	if err := ensureMigrationsTable(ctx, pool); err != nil {
		return 0, err
	}
	migs, err := loadMigrations()
	if err != nil {
		return 0, err
	}
	_, max, err := appliedVersions(ctx, pool)
	if err != nil {
		return 0, err
	}
	if max == 0 {
		return 0, nil
	}
	for _, m := range migs {
		if m.version != max {
			continue
		}
		err := runInTx(ctx, pool, func(tx pgx.Tx) error {
			if m.down != "" {
				if _, err := tx.Exec(ctx, m.down); err != nil {
					return fmt.Errorf("migration %04d_%s down: %w", m.version, m.name, err)
				}
			}
			_, err := tx.Exec(ctx, `DELETE FROM schema_migrations WHERE version = $1`, m.version)
			return err
		})
		return max, err
	}
	return 0, fmt.Errorf("no migration file for version %d", max)
}

// MigrateVersion returns the current schema version (0 = none applied).
func MigrateVersion(ctx context.Context, pool *pgxpool.Pool) (int64, error) {
	if err := ensureMigrationsTable(ctx, pool); err != nil {
		return 0, err
	}
	_, max, err := appliedVersions(ctx, pool)
	return max, err
}

func runInTx(ctx context.Context, pool *pgxpool.Pool, fn func(pgx.Tx) error) error {
	tx, err := pool.Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx)
	if err := fn(tx); err != nil {
		return err
	}
	return tx.Commit(ctx)
}
