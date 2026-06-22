// Command api is the single Raai binary: it serves the HTTP API + admin dashboard
// and also carries the deploy/ops subcommands (migrate, admin, healthcheck) so the
// same image can run migrations as a one-shot job and seed the first admin (§9).
package main

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"net"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/jackc/pgx/v5"
	"raai/internal/config"
	"raai/internal/db"
	"raai/internal/db/sqlc"
	"raai/internal/server"
)

var version = "dev"

func main() {
	slog.SetDefault(slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{Level: slog.LevelInfo})))

	cmd := "serve"
	if len(os.Args) > 1 {
		cmd = os.Args[1]
	}

	var err error
	switch cmd {
	case "serve":
		err = serve()
	case "migrate":
		err = runMigrate(os.Args[2:])
	case "admin":
		err = runAdmin(os.Args[2:])
	case "healthcheck":
		err = runHealthcheck()
	case "version":
		fmt.Println(version)
	default:
		err = fmt.Errorf("unknown command %q (want: serve|migrate|admin|healthcheck|version)", cmd)
	}
	if err != nil {
		slog.Error("fatal", "cmd", cmd, "err", err)
		os.Exit(1)
	}
}

func serve() error {
	cfg, err := config.Load()
	if err != nil {
		return err
	}

	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()

	pool, err := db.NewPool(ctx, cfg.DatabaseURL)
	if err != nil {
		return fmt.Errorf("connect db: %w", err)
	}
	defer pool.Close()

	app, err := server.New(cfg, pool)
	if err != nil {
		return err
	}

	go expirySweep(ctx, app.Queries)

	srv := &http.Server{
		Addr:              cfg.Addr,
		Handler:           app.Handler,
		ReadHeaderTimeout: 10 * time.Second,
		ReadTimeout:       30 * time.Second,
		WriteTimeout:      30 * time.Second,
		IdleTimeout:       120 * time.Second,
	}

	errCh := make(chan error, 1)
	go func() {
		slog.Info("listening", "addr", cfg.Addr, "version", version)
		if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			errCh <- err
		}
	}()

	select {
	case err := <-errCh:
		return err
	case <-ctx.Done():
		slog.Info("shutting down")
		shutdownCtx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
		defer cancel()
		return srv.Shutdown(shutdownCtx)
	}
}

// expirySweep flips lapsed subscriptions to expired so the gate returns 402 (§7.6).
func expirySweep(ctx context.Context, q *sqlc.Queries) {
	tick := time.NewTicker(time.Hour)
	defer tick.Stop()
	for {
		if n, err := q.ExpireSubscriptions(ctx); err != nil {
			slog.Error("expiry sweep failed", "err", err)
		} else if n > 0 {
			slog.Info("expiry sweep", "expired", n)
		}
		select {
		case <-ctx.Done():
			return
		case <-tick.C:
		}
	}
}

func runMigrate(args []string) error {
	action := "up"
	if len(args) > 0 {
		action = args[0]
	}
	cfg, err := config.Load()
	if err != nil {
		return err
	}
	ctx := context.Background()
	pool, err := db.NewPool(ctx, cfg.DatabaseURL)
	if err != nil {
		return err
	}
	defer pool.Close()

	switch action {
	case "up":
		n, err := db.MigrateUp(ctx, pool)
		if err != nil {
			return err
		}
		slog.Info("migrate up complete", "applied", n)
	case "down":
		v, err := db.MigrateDown(ctx, pool)
		if err != nil {
			return err
		}
		slog.Info("migrate down complete", "rolled_back_version", v)
	case "version":
		v, err := db.MigrateVersion(ctx, pool)
		if err != nil {
			return err
		}
		fmt.Printf("schema version: %d\n", v)
	default:
		return fmt.Errorf("unknown migrate action %q (want: up|down|version)", action)
	}
	return nil
}

// runAdmin implements `api admin grant <phone>` to seed the first admin (§8.4).
func runAdmin(args []string) error {
	if len(args) < 2 || args[0] != "grant" {
		return fmt.Errorf("usage: api admin grant <phone>")
	}
	phone := args[1]
	cfg, err := config.Load()
	if err != nil {
		return err
	}
	ctx := context.Background()
	pool, err := db.NewPool(ctx, cfg.DatabaseURL)
	if err != nil {
		return err
	}
	defer pool.Close()

	user, err := sqlc.New(pool).SetAdminByPhone(ctx, phone)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return fmt.Errorf("no user with phone %q", phone)
		}
		return err
	}
	slog.Info("granted admin", "user_id", user.ID, "phone", user.PhoneNumber)
	return nil
}

// runHealthcheck is the tiny in-container probe for distroless (no shell) (§9.3).
func runHealthcheck() error {
	addr := os.Getenv("ADDR")
	if addr == "" {
		addr = ":8080"
	}
	_, port, err := net.SplitHostPort(addr)
	if err != nil {
		port = "8080"
	}
	client := &http.Client{Timeout: 3 * time.Second}
	resp, err := client.Get("http://127.0.0.1:" + port + "/healthz")
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("healthcheck status %d", resp.StatusCode)
	}
	return nil
}
