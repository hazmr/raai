# Raai (راعي) — Backend

This is the backend (server) for **Raai**, a livestock-notes app: a farmer scans an
animal's ear-tag barcode and keeps notes on it; a visiting **vet** can add medical notes
during an authorized visit; farmers pay a subscription via **InstaPay**.

> **New to Go?** You don't need to know Go to run this. Everything runs through **Docker**
> with two commands. The "Run it with Docker" section below is all you need. The Go
> details are further down for when you're curious.

---

## What's in here

- A web server that exposes a JSON API at **`/api/v1/...`** (used by the mobile app).
- An **admin dashboard** (a website) at **`/admin`** where you approve InstaPay payments.
- A **PostgreSQL** database (runs as a second container).

You talk to it over HTTP on **port 8080**:
- API base URL: `http://localhost:8080/api/v1`
- Admin dashboard: `http://localhost:8080/admin`
- Health check: `http://localhost:8080/healthz`

---

## Prerequisites

Just **Docker** (with the Compose plugin). Check you have it:

```bash
docker --version
docker compose version
```

You do **not** need Go, PostgreSQL, or anything else installed to run it.

---

## 1. Configure (one time)

Copy the example settings file to `.env` and edit it:

```bash
cp .env.example .env
```

Open `.env` and set at least these:

| Variable | What it is | Example |
|----------|-----------|---------|
| `JWT_KEY` | Secret used to sign login tokens. **Make this long and random.** | run `openssl rand -base64 48` and paste the result |
| `SECURE_COOKIES` | `true` in production (HTTPS). Set `false` for local testing on `http://`. | `false` locally |
| `INSTAPAY_IPA` | Your InstaPay address shown to users on the paywall | `yourname@instapay` |
| `INSTAPAY_DISPLAY_NAME` | Your name shown on the paywall | `Hazem Ahmed` |
| `PRICE_MONTHLY_EGP` / `PRICE_YEARLY_EGP` | Subscription prices in EGP | `150` / `1500` |

`DB_CONNECTION_STRING` is already set correctly for Docker — leave it as is.

> ⚠️ **Never commit `.env`** — it holds secrets. It's already in `.gitignore`.

---

## 2. Run it with Docker

```bash
docker compose up -d --build
```

That one command does three things in order:
1. starts **PostgreSQL** and waits until it's ready,
2. runs **database migrations** (creates the tables) — a one-shot job that then exits,
3. starts the **API server** on port 8080.

`-d` means "detached" (runs in the background so your terminal stays free).

Check everything is up:

```bash
docker compose ps
```

You should see `db` and `api` as **running/healthy**, and `migrate` as **exited (0)**
(that's correct — it's a one-time job).

Test it:

```bash
curl http://localhost:8080/healthz
# -> {"status":"ok"}
```

---

## 3. Create your admin user

There is **no default admin** (for security). You create one in two steps:

```bash
# a) Register a normal account — YOU choose the phone and password:
curl -X POST http://localhost:8080/api/v1/auth/register \
  -H 'Content-Type: application/json' \
  -d '{"phoneNumber":"01000000000","password":"choose-a-strong-password"}'

# b) Promote that phone to admin:
docker compose exec api /api admin grant 01000000000
```

Now log in to the dashboard at **http://localhost:8080/admin/login** with that phone and
password.

> To add **more** admins later, repeat both steps with a different phone. There is no
> "add admin" button in the dashboard — promoting to admin is only done from the command
> line, on purpose, so a stolen login can't create new admins.

---

## 4. Everyday commands

```bash
docker compose logs -f api     # watch the server's logs live (Ctrl+C to stop watching)
docker compose ps              # see what's running
docker compose restart api     # restart just the server
docker compose down            # stop everything (keeps the database data)
docker compose down -v         # stop everything AND erase the database (fresh start)
docker compose up -d --build   # rebuild and start after you change code
```

If you change `.env`, apply it with:

```bash
docker compose up -d           # recreates containers with the new settings
```

---

## How the app works (the big picture)

**Two kinds of users** (set when they register, field `role`):
- **farmer** — owns the herd, pays the subscription, full access to their own animals/notes.
- **vet** — a visiting doctor. Can only see a farmer's animals and add notes **while the
  farmer has opened a "visit"** for them. Closing the visit ends the vet's access.

**Logging in** returns two tokens:
- an **access token** (valid 1 hour) — sent on every request as `Authorization: Bearer <token>`,
- a **refresh token** (valid 7 days) — used to get a new access token without logging in again.

**The paywall:** animal/note/visit endpoints are locked until the **farmer** has an active
subscription. If not, the API returns HTTP **402** and the app shows the "pay with
InstaPay" screen.

**Billing (InstaPay):** InstaPay has no automatic payment confirmation, so:
1. the user transfers money to your InstaPay address and gets a **reference number**,
2. they submit that reference in the app (`POST /billing/payments`),
3. **you** (admin) check your bank, then click **Confirm** in the dashboard,
4. confirming extends their subscription. Done.

---

## API quick reference

Base URL: `http://localhost:8080/api/v1`. All responses are JSON. Errors always look like
`{"error":{"code":"...","message":"..."}}`.

| What | Method & path | Needs login? |
|------|---------------|--------------|
| Register | `POST /auth/register` | no |
| Log in | `POST /auth/login` | no |
| Refresh tokens | `POST /auth/refresh` | no |
| Log out | `POST /auth/logout` | yes |
| Who am I | `GET /me` | yes |
| List/create animals | `GET` / `POST /animals` | yes (+ subscription) |
| One animal | `GET`/`PATCH`/`DELETE /animals/{id}` | yes (+ subscription) |
| Find by barcode | `GET /animals?barcode=TAG-001` | yes (+ subscription) |
| Notes on an animal | `GET`/`POST /animals/{id}/notes` | yes (+ subscription) |
| Subscription status | `GET /billing/status` | yes |
| Plans + your InstaPay handle | `GET /billing/plans` | yes |
| Submit a payment | `POST /billing/payments` | yes |
| Open/close visits | `POST /visits`, `POST /visits/{id}/close` | yes (+ subscription) |
| Admin: review payments | `GET /admin/payments?status=pending` | yes (admin) |

**Example: log in and call a protected endpoint**

```bash
# log in -> copy the "accessToken" from the response
curl -X POST http://localhost:8080/api/v1/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"phoneNumber":"01000000000","password":"your-password"}'

# use the token
curl http://localhost:8080/api/v1/me \
  -H 'Authorization: Bearer PASTE_ACCESS_TOKEN_HERE'
```

---

## Project structure (for the curious)

```
server/
  cmd/api/main.go        # entry point + subcommands (serve, migrate, admin, healthcheck)
  internal/
    config/              # reads settings from environment variables
    db/                  # database connection + migration runner + generated query code
    httpx/               # shared helpers (errors, JSON, pagination)
    auth/                # registration, login, passwords, tokens
    animals/  notes/     # the herd and its notes
    visits/              # vet visit lifecycle
    billing/             # subscriptions + InstaPay payments + the paywall
    admin/               # admin dashboard + payment approval
    middleware/          # logging, crash recovery, rate limiting
    server/              # wires all the above into one web server
  web/                   # admin dashboard HTML + CSS (built into the binary)
  migrations/            # SQL files that create/update the database tables
  Dockerfile             # how the server image is built
  docker-compose.yml     # runs db + migrations + server together
  .env.example           # template for your .env settings
```

---

## Running without Docker (optional, needs Go)

Only if you want to develop the Go code directly. Install Go 1.26+, then:

```bash
# point it at a Postgres you're running, and set a secret:
export DB_CONNECTION_STRING="postgres://raai:raai@localhost:5432/raai?sslmode=disable"
export JWT_KEY="dev-secret" SECURE_COOKIES=false

go run ./cmd/api migrate up    # create tables
go run ./cmd/api serve         # start the server
```

There's a `Makefile` with shortcuts: `make run`, `make migrate-up`, `make test`, `make fmt`.

If you change the database queries in `internal/db/queries/*.sql`, regenerate the Go code
with `sqlc generate` (requires the `sqlc` tool).

---

## Troubleshooting

**`service "migrate" didn't complete successfully`** — usually the database wasn't ready or
a setting is wrong. Check the logs: `docker compose logs migrate`.

**`phone number is already registered` (409)** — that phone already has an account. Just go
straight to the `admin grant` step, or log in with it.

**Can't log in to `/admin`** — make sure you ran `admin grant` for that phone, and that
you're using the same password you registered with. Only admins can log into `/admin`.

**Cookies / login not sticking on `http://localhost`** — set `SECURE_COOKIES=false` in
`.env` and run `docker compose up -d` again. (Use `true` in production with HTTPS.)

**Start completely fresh** (wipes all data):

```bash
docker compose down -v && docker compose up -d --build
```
