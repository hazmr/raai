# Raai (راعي) — Backend (Go)

Go rebuild of the Raai livestock-notes API: a clean, versioned **`/api/v1`** REST
contract, two roles (**farmer** owner + visiting **vet**), and an **InstaPay**
subscription paywall with an **admin dashboard**. Single static binary, scale-to-zero.

Full spec: [`../SYSTEM_DESIGN.md`](../SYSTEM_DESIGN.md). Section refs below (§) point there.

## Stack

- **Go 1.26**, router **chi**, Postgres via **pgx + sqlc** (type-safe SQL, no ORM).
- JWT **HS256** (`golang-jwt/v5`), passwords **bcrypt** (never plaintext).
- Migrations: embedded SQL run by a `migrate` subcommand — **never on startup** (§10.2).
- Admin dashboard: `html/template` + a little CSS, **`go:embed`-ed** into the binary.
- Config: **env vars only** (12-factor).

## Layout

```
cmd/api/main.go          # subcommands: serve | migrate | admin | healthcheck | version
internal/
  config/                # env loading
  db/                    # pgx pool, migration runner, sqlc-generated code (sqlc/)
  httpx/                 # error envelope, JSON, cursor pagination
  auth/                  # bcrypt, JWT, middleware, register/login/refresh/logout, /me
  animals/ notes/        # animals + nested notes
  visits/                # visit lifecycle + vet access
  billing/              # InstaPay plans/status/payments + the paywall gate
  admin/                 # shared admin service + JSON endpoints + dashboard
  middleware/            # logging, panic recovery, rate limit
  server/                # router wiring
web/{templates,static}/  # admin dashboard assets (embedded)
migrations/              # 0001_init, 0002_roles_visits, 0003_subscriptions (.up/.down)
```

## Quick start (local)

```bash
cp .env.example .env          # set JWT_KEY at minimum; SECURE_COOKIES=false for HTTP

# Option A — everything in Docker (Postgres + migrate job + api):
docker compose up --build

# Option B — local binary against your own Postgres:
export DB_CONNECTION_STRING="postgres://raai:raai@localhost:5432/raai?sslmode=disable"
export JWT_KEY="dev-secret" SECURE_COOKIES=false
go run ./cmd/api migrate up      # apply migrations (one-shot)
go run ./cmd/api serve           # start the server on :8080
go run ./cmd/api admin grant 01000000000   # seed your first admin (§8.4)
```

Dashboard: http://localhost:8080/admin · Health: `/healthz` (no DB), `/readyz` (pings DB).

## Regenerating DB code

Edit SQL in `internal/db/queries/*.sql` (schema lives in `migrations/`), then:

```bash
sqlc generate     # or: make sqlc
```

## API surface (`/api/v1`)

All responses use the error envelope `{"error":{"code","message"}}` (§6.6). Lists are
cursor-paginated and wrapped `{"data":[...],"nextCursor":...}`. All routes except
`auth/*` require `Authorization: Bearer <token>`. Animal/note/visit routes are behind
the **subscription paywall** (`402 subscription_required` when the owning farmer lapses).

| Area | Endpoints |
|------|-----------|
| Auth (§6.2) | `POST auth/{register,login,refresh,logout}` |
| Me (§6.3) | `GET me` |
| Animals (§6.4) | `GET/POST animals`, `GET/PATCH/DELETE animals/{id}`, `?barcode=`, `?include=notes` |
| Notes (§6.5) | `GET/POST animals/{id}/notes`, `GET/PATCH/DELETE animals/{id}/notes/{id}` |
| Visits (§6.8) | `POST/GET visits`, `POST visits/{id}/close`, `GET visits/{id}/animals` |
| Billing (§7.3) | `GET billing/{plans,status,payments}`, `POST billing/payments` |
| Admin JSON (§7.3) | `GET admin/payments`, `POST admin/payments/{id}/{confirm,reject}` |

### Roles & visits (§4.3)
- **Farmer** owns the herd, pays, full CRUD. **Vet** reads a farmer's animals and adds
  notes **only inside an `open` visit** the farmer authorized (server sets author fields).
- A vet writes via the same `POST animals/{id}/notes` with `visitId`. Closing the visit
  ends the vet's access.

### Billing (§7) — InstaPay manual verify
InstaPay has no merchant API/webhook, so: user transfers to your IPA → submits the
reference (`POST billing/payments`) → **admin confirms**, which in one transaction marks
the payment confirmed and extends `current_period_end` from `max(now, current_period_end)`
so renewals stack. `instapay_ref` is UNIQUE (dedupes claims). An hourly sweep expires
lapsed subscriptions.

## Deployment (§9)

Multi-stage distroless non-root `Dockerfile` → ~static image. Run migrations as a
discrete job (`/api migrate up`) before the app rolls out — Fly `release_command`, a k8s
init Job, or the Compose `migrate` service (`service_completed_successfully`). All secrets
injected at runtime via platform secrets; nothing baked into a layer.

## Verified flows

Smoke-tested end-to-end against Postgres 16: register/login (409 on dup, 401 on bad
creds), paywall `402`, payment submit (idempotent on reused ref) → admin confirm →
access granted, animals CRUD + barcode filter + `include=notes`, cursor pagination,
the full vet visit lifecycle (open → herd → note with `visitId` → `422` without →
`403` after close), and the cookie+CSRF admin dashboard.
