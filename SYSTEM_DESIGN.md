# Raai (راعي) — Backend System Design (Go rebuild)

> **Raai** (راعي, *"herder / shepherd"*) — a livestock notes app: scan an animal's
> ear-tag barcode, keep its records, watch over the whole herd. Subscriptions are paid
> via InstaPay (Egypt). *(Formerly working-named "VetNotes".)*

A spec to rebuild the Raai backend in **Go** with a **redesigned, versioned
`/api/v1` HTTP API**, and adding **monthly / yearly subscriptions** paid via
**InstaPay** (Egypt's instant payment network).

> 🔁 **Clean-break API.** This is a redesign, not a like-for-like port. The new
> contract (§6) drops the old ASP.NET quirks (notes addressed by barcode, full notes
> embedded in every animal, no register endpoint, ad-hoc errors). **The Kotlin/Android
> client must be updated to match.** The old data model carries over; the HTTP surface
> does not.

> ⚠️ **InstaPay reality check.** InstaPay is the Central Bank of Egypt's P2P instant
> transfer network (IPN). For an individual / small merchant there is **no public
> payment API, no SDK, and no server webhooks** — you cannot create a charge from code
> or get an automatic callback when money lands. Users transfer money **manually** to
> your **IPA** (InstaPay address, e.g. `yourname@instapay`) or phone/wallet, and each
> transfer yields a **reference number**. This design therefore uses **manual /
> assisted verification**: the user submits the reference, an **admin confirms** it,
> and the subscription activates. (If you later get a real bank merchant-collection
> API or a "merchant IPA", you can automate §7.5 without changing the rest.)

> Reference (what we're replacing): the existing ASP.NET Core API
> (`/api/auth`, `/api/animals`, `/api/animals/{barcode}/notes`). Useful only for
> understanding current behavior — the new API in §6 supersedes it.

---

## 1. Goals

- Rebuild in Go for the **lowest production cost** (small memory footprint, scale-to-zero hosts).
- Ship a **clean, versioned `/api/v1` REST contract** (§6); the Android client updates to match.
- Support a **farm tenant**: an admin who pays, the farmers working with them, and
  **visiting doctors** who write notes under a revocable invite — see §4.3.
- Add a **subscription paywall**: the **farmer** pays monthly or yearly **via InstaPay**.
- Since InstaPay has no merchant API, support a **submit-reference → admin-confirm** flow.
- Add a small **admin web dashboard** to review/confirm InstaPay payments (see §8).
- Fix two issues carried over from the current backend (see §10).

## 2. Recommended Go stack

| Concern        | Choice                          | Why                                                   |
|----------------|---------------------------------|-------------------------------------------------------|
| Language       | Go 1.22+                        | Tiny RAM, fast cold start, single static binary       |
| HTTP router    | `chi`                          | Stdlib-compatible, middleware-friendly, no magic      |
| DB             | **PostgreSQL**                 | Free, cheap managed tiers everywhere                  |
| DB access      | `pgx` + **`sqlc`**             | Type-safe SQL from plain queries; no heavy ORM        |
| Migrations     | `golang-migrate` (or `goose`)  | Versioned SQL migrations run as a deploy step         |
| JWT            | `golang-jwt/jwt/v5`            | HMAC-SHA256 tokens, same scheme as today              |
| Password hash  | `golang.org/x/crypto/bcrypt`   | Replace today's plaintext passwords                   |
| Config         | env vars (`os.Getenv`)         | Matches current env-first config                      |
| Payments       | **InstaPay** (manual / assisted verify) | No merchant API — see §7                      |

> Coming from EF Core, `GORM` will feel more familiar than `sqlc`. It's a fine
> alternative; `sqlc` is just leaner and faster. Pick one and stay consistent.

## 3. Suggested project layout

```
raai-go/
  cmd/api/main.go            # wiring: config, db pool, router, server
  internal/
    config/                  # env loading
    db/                      # pgx pool, sqlc-generated code, migrations/
    auth/                    # JWT issue/verify, password hashing, middleware
    animals/                 # handlers + queries
    notes/                   # handlers + queries
    billing/                 # subscriptions + InstaPay payment submit/confirm
    admin/                   # admin dashboard: handlers + payment review service
    middleware/              # auth, subscription gate, logging, rate limit
  web/
    templates/               # html/template files for the admin dashboard (go:embed)
    static/                  # tiny CSS (+ optional htmx.min.js), embedded
  migrations/                # 0001_init.sql, 0002_subscriptions.sql, ...
  Dockerfile
```

---

## 4. Data model

### 4.1 Existing tables (carry over as-is)

**users**
| column                    | type        | notes                              |
|---------------------------|-------------|------------------------------------|
| id                        | serial PK   |                                    |
| phone_number              | text        | UNIQUE, required                   |
| password                  | text        | **store bcrypt hash** (see §9)     |
| refresh_token             | text NULL   | rotated on each refresh            |
| refresh_token_expiry_time | timestamptz NULL |                               |
| is_admin                  | bool        | default `false` — can confirm payments |
| role                      | text        | `farmer` \| `vet` (default `farmer`) — see §4.3 |
| created_at                | timestamptz | default `now()`                    |

**animals** (owned by the **farm**, not by one user — see §4.3)
| column     | type        | notes                                   |
|------------|-------------|-----------------------------------------|
| id         | serial PK   |                                         |
| barcode    | text        | required                                |
| farm_id    | int FK→farms| ON DELETE CASCADE                       |
| created_at | timestamptz | default `now()`                         |
| updated_at | timestamptz | default `now()`                         |
|            |             | UNIQUE (`barcode`, `farm_id`) — the same tag may exist in another farm |

**animal_notes**
| column           | type           | notes                          |
|------------------|----------------|--------------------------------|
| id               | serial PK      |                                |
| animal_id        | int FK→animals | ON DELETE CASCADE              |
| notes            | text           | required (exposed as `body` in the API, §6.5) |
| author_kind      | text           | `member` \| `doctor` — UI badges a doctor's note |
| author_user_id   | int FK→users NULL | set when a farm member wrote it |
| author_invite_id | int FK→doctor_invites NULL | set when an invited doctor wrote it |
| author_label     | text           | display name **stamped at write time**, so history survives even if the author row is later removed |
| created_at       | timestamptz    | default `now()`                |
| updated_at       | timestamptz    | default `now()`                |

### 4.2 New tables for subscriptions

**subscriptions** (one row per **farm** — the farm is what is paid for)
| column                | type        | notes                                                   |
|-----------------------|-------------|---------------------------------------------------------|
| id                    | serial PK   |                                                         |
| farm_id               | int FK→farms| UNIQUE                                                  |
| plan                  | text        | `monthly` \| `yearly`                                   |
| status                | text        | `pending` \| `active` \| `expired`                      |
| current_period_end    | timestamptz | access is allowed while `now() < current_period_end`    |
| created_at            | timestamptz | default `now()`                                         |
| updated_at            | timestamptz | default `now()`                                         |

> No `provider` / `trialing` / `past_due` here — there's no gateway pushing state.
> Access is driven entirely by `current_period_end`, which an admin extends when a
> payment is confirmed (§7.5). `status` is mostly derived: `active` while inside the
> period, `expired` after, `pending` if they've submitted a payment not yet confirmed.

**payments** (one row per claimed InstaPay transfer — the audit trail + idempotency)
| column            | type        | notes                                                       |
|-------------------|-------------|-------------------------------------------------------------|
| id                | serial PK   |                                                             |
| farm_id           | int FK→farms| the farm this transfer pays for                             |
| created_by        | int FK→users NULL | the member who submitted the reference                |
| plan              | text        | `monthly` \| `yearly` the user is paying for                |
| amount_egp        | numeric     | amount the user claims they sent (EGP)                      |
| instapay_ref      | text        | UNIQUE — the InstaPay transaction reference (dedupe claims) |
| screenshot_url    | text NULL   | optional proof upload                                       |
| status            | text        | `pending` \| `confirmed` \| `rejected`                      |
| reviewed_by       | int FK→users NULL | admin who confirmed/rejected                          |
| reviewed_at       | timestamptz NULL |                                                       |
| note              | text NULL   | admin note (e.g. reason for rejection)                      |
| created_at        | timestamptz | default `now()` — when the user submitted it                |

> `instapay_ref UNIQUE` stops the same transfer being submitted twice. Confirming a
> `payments` row is what advances the matching `subscriptions.current_period_end`.

**admin_audit** (who did what in the dashboard — accountability)
| column      | type        | notes                                                          |
|-------------|-------------|----------------------------------------------------------------|
| id          | serial PK   |                                                                |
| admin_id    | int FK→users|                                                                |
| action      | text        | `confirm_payment` \| `reject_payment` \| `grant` \| `revoke`   |
| target_user | int FK→users NULL | user affected                                            |
| payment_id  | int FK→payments NULL |                                                       |
| detail      | text NULL   | e.g. "+1 month", reason for rejection                          |
| created_at  | timestamptz | default `now()`                                                |

### 4.3 Farms, members & doctor invites

Raai is **farm-tenanted**: the farm owns the herd, and everyone reaches it through the
farm. Three kinds of principal:

- **Farm admin** — registers the farm, *buys the subscription*, adds farmers, invites
  doctors. Full read/write.
- **Farm member (farmer)** — works the herd: reads and writes animals and notes. No
  billing, no member management, no invites.
- **Visiting doctor** — a vet with **no account at all**. The admin creates an invite,
  the app renders it as a QR code, and the doctor scans it to get a short-lived session
  scoped to that one farm. Ending the invite revokes access on the doctor's very next
  request.

> **Why invites and not vet accounts.** A visiting vet shouldn't need to register, be
> promoted, or be assigned to a "visit" before they can write a note — in a barn, with
> the farmer standing there, the admin shows a QR and the vet is in. The invite *is*
> the grant: it is time-boxed, revocable, and every note it produced stays in the
> animal's history after it ends.

**farms**
| column     | type        | notes                        |
|------------|-------------|------------------------------|
| id         | serial PK   |                              |
| name       | text        | shown in the app's title bar |
| created_at | timestamptz | default `now()`              |

**farm_members**
| column     | type        | notes                                              |
|------------|-------------|----------------------------------------------------|
| id         | serial PK   |                                                    |
| farm_id    | int FK→farms| ON DELETE CASCADE                                  |
| user_id    | int FK→users| **UNIQUE** — one farm per user                     |
| role       | text        | `admin` \| `farmer`                                |
| created_at | timestamptz | default `now()`                                    |

**doctor_invites**
| column       | type        | notes                                                  |
|--------------|-------------|--------------------------------------------------------|
| id           | serial PK   |                                                        |
| farm_id      | int FK→farms| ON DELETE CASCADE                                      |
| token        | text        | UNIQUE — the cryptographically random secret in the QR  |
| doctor_label | text        | the name shown on their notes and in the history        |
| status       | text        | `active` \| `ended`                                    |
| expires_at   | timestamptz NULL | null = no expiry, ended manually                   |
| created_by   | int FK→users NULL |                                                   |
| created_at   | timestamptz | default `now()`                                        |
| ended_at     | timestamptz NULL |                                                   |
| ended_by     | int FK→users NULL |                                                   |

**Permission rules** (enforced in middleware + handlers, always *also* scoped by farm):

- **Everything is scoped to `farm_id`.** A caller only ever sees their own farm's herd;
  another farm's animal id returns `404`, never `403` (§6.6).
- **Farm admin**: everything below, plus members (§6.9), invites (§6.8) and billing (§7.3).
- **Member**: full CRUD on the farm's animals; may write notes; may edit or delete only
  **their own** notes.
- **Doctor**: reads the farm's herd, may **register** a freshly-scanned ear tag, and
  writes notes stamped `authorKind: "doctor"`. May **not** edit or delete animals
  (`403`), manage the farm, or touch anyone else's notes.
- **Authorship is re-checked per request**, not trusted from the token: the auth
  middleware loads the user's membership (or the invite's `status`/`expires_at`) on
  every call, so removing a member or ending an invite takes effect immediately.

**Billing interaction:** the paywall (§7.2) keys off the **farm**. If the farm's
subscription lapses, the herd locks for everyone touching it — members and invited
doctors alike — while auth, `/me`, billing and member management stay reachable so the
admin can pay. Redeeming an invite into a lapsed farm returns `402`.

> **Writing notes in the field** (the "how do they actually type it" worry): the note
> API stays one `body` string and the ergonomics live in the client — **quick
> templates** (tap "vaccination / checkup / treatment"), **voice dictation**, and an
> **offline outbox** (write in the barn with no signal, sync later; the
> `Idempotency-Key` on every queued POST, §6.1, makes the replay safe).

---

## 5. Auth design

- **Register** (`POST /api/v1/auth/register`): create a user with a unique
  `phone_number` + bcrypt-hashed password, then issue tokens (same shape as login).
  `409` if the phone is taken. *(New — the old API had no register endpoint.)*
- **Login** (`POST /api/v1/auth/login`): look up user by `phone_number`, verify
  password, issue access token (1h) + refresh token (7d), store rotated refresh token.
- **Access token**: JWT HS256 with claims `sub`(=uid), `phone`, `jti`,
  `iss`/`aud`/`exp` from env. Signed with `JWT_KEY`.
- **Refresh** (`POST /api/v1/auth/refresh`): look up user by stored refresh token,
  reject if missing/expired, otherwise rotate and re-issue both tokens.
- **Logout** (`POST /api/v1/auth/logout`, auth required): clear stored refresh token.
- **Auth middleware**: validate Bearer JWT, extract `uid` → request context.
  Reject with `401` if invalid/expired.

Env vars (same names as today): `JWT_KEY`, `JWT_ISSUER`, `JWT_AUDIENCE`,
`DB_CONNECTION_STRING` (Postgres DSN), plus billing vars in §7.

---

## 6. HTTP API contract (redesigned — `/api/v1`)

A clean REST surface. Everything lives under **`/api/v1`**. All routes except
`register` / `login` / `refresh` and the billing webhooks require
`Authorization: Bearer <token>`. **User scoping:** every query is filtered by the
`uid` from the token — a user only ever sees their own animals/notes.

### 6.1 Conventions

- **JSON, camelCase** fields. In Go set `json:"..."` tags accordingly.
- **Timestamps**: RFC 3339 UTC strings (e.g. `2026-06-22T10:00:00Z`), named
  `createdAt` / `updatedAt`.
- **IDs** are integers in the path; sub-resources nest under their parent's **id**
  (notes under `animals/{animalId}`, never under barcode).
- **Errors** use one envelope: `{ "error": { "code": "...", "message": "..." } }`
  with a machine-readable `code` (snake_case). See §6.6.
- **Lists are paginated** (cursor-based) and wrapped: `{ "data": [...], "nextCursor": "..." }`.
  `nextCursor` is `null`/absent on the last page. Query: `?limit=50&cursor=<opaque>`
  (`limit` default 50, max 200).
- **Partial updates** use `PATCH`; bodies send only changed fields.
- **Idempotency**: any authenticated `POST` accepts an optional `Idempotency-Key`
  header, so the app's offline outbox can replay a queued write without double-creating.
  The first request stores its response against `(farm, key)`; a replay of the **same**
  request gets that response back with `Idempotent-Replay: true`. Reusing a key for a
  *different* body is `409`. Only `2xx` responses are stored — a failed attempt releases
  the key, so a note POSTed before its animal finished syncing can succeed on retry.
  Keys are purged after 24h by the hourly sweep. Recommended for every queued write;
  most valuable on payment submit (§7).

### 6.2 Auth
| Method | Path                    | Body                       | Success | Errors |
|--------|-------------------------|----------------------------|---------|--------|
| POST   | `/api/v1/auth/register` | `{phoneNumber, password}`  | `201` AuthTokens | `409` taken, `422` invalid |
| POST   | `/api/v1/auth/login`    | `{phoneNumber, password}`  | `200` AuthTokens | `401` |
| POST   | `/api/v1/auth/refresh`  | `{refreshToken}`           | `200` AuthTokens | `401` |
| POST   | `/api/v1/auth/logout`   | —                          | `204`   | `401`  |

`AuthTokens`: `{accessToken, refreshToken, tokenType: "Bearer", expiresAt}`.

### 6.3 Current user
| Method | Path           | Body | Success | Errors |
|--------|----------------|------|---------|--------|
| GET    | `/api/v1/me`   | —    | `200` User | `401` |

`User`: `{id, phoneNumber, isAdmin, createdAt}`. (Billing state is its own endpoint, §7.3.)

### 6.4 Animals
| Method | Path                       | Body                | Success | Errors |
|--------|----------------------------|---------------------|---------|--------|
| GET    | `/api/v1/animals`          | —                   | `200` List<Animal> | `401` |
| GET    | `/api/v1/animals/{id}`     | —                   | `200` Animal | `404` |
| POST   | `/api/v1/animals`          | `{barcode}`         | `201` Animal | `409` duplicate, `422` |
| PATCH  | `/api/v1/animals/{id}`     | `{barcode}`         | `200` Animal | `404`, `409`, `422` |
| DELETE | `/api/v1/animals/{id}`     | —                   | `204`   | `404` |

- **Barcode lookup** is a filter, not a special route: `GET /api/v1/animals?barcode=XYZ`
  → a (0- or 1-element) `data` list, since barcode is unique per user. Replaces the old
  `/by-barcode/{barcode}`.
- `Animal`: `{id, barcode, noteCount, createdAt, updatedAt}` — notes are **no longer
  embedded** (they're a paginated sub-resource). Pass `?include=notes` to embed the
  first page of notes when you really want them in one round-trip.

### 6.5 Notes (nested under animal **id**)
| Method | Path                                    | Body        | Success | Errors |
|--------|-----------------------------------------|-------------|---------|--------|
| GET    | `/api/v1/animals/{animalId}/notes`      | —           | `200` List<Note> | `404` no animal |
| GET    | `/api/v1/animals/{animalId}/notes/{id}` | —           | `200` Note | `404` |
| POST   | `/api/v1/animals/{animalId}/notes`      | `{body}`    | `201` Note | `404`, `422` |
| PATCH  | `/api/v1/animals/{animalId}/notes/{id}` | `{body}`    | `200` Note | `404`, `422` |
| DELETE | `/api/v1/animals/{animalId}/notes/{id}` | —           | `204`   | `404` |

- `Note`: `{id, animalId, body, authorKind, authorLabel, inviteId, createdAt, updatedAt}`.
  The text field is renamed `notes` → **`body`** (a note's text isn't "notes").
  `authorKind` (`member`\|`doctor`) lets the UI badge a visiting doctor's note;
  `authorLabel` is the display name stamped when the note was written, so an ended
  invite or a removed member never blanks out the history. `inviteId` is set only for a
  doctor's note.
- **Every author field is set server-side from the token** — the client sends only
  `{body}`. A doctor's session already names the farm and the invite.
- Editing and deleting are **author-only**: a member may change their own notes, a
  doctor their own. Someone else's note answers `404` (§6.6), so the API doesn't confirm
  what it won't let you touch.
- Default order: `createdAt` **descending**; cursor-paginated.

### 6.6 Status codes & error envelope

Every error response: `{ "error": { "code", "message" } }`.

| Status | When | Example `code` |
|--------|------|----------------|
| `400` | Malformed JSON / bad query param | `bad_request` |
| `401` | Missing/invalid/expired token | `unauthorized` |
| `402` | Subscription required (paywall, §7.2) | `subscription_required` |
| `403` | Authenticated but not allowed (e.g. admin-only) | `forbidden` |
| `404` | Resource missing or not owned by caller | `not_found` |
| `409` | Uniqueness conflict (duplicate barcode / reused `instapayRef`) | `conflict` |
| `422` | Validation failed | `validation_error` (+ optional `fields`) |
| `429` | Rate-limited | `rate_limited` |
| `500` | Unexpected | `internal_error` |

> A `404` (not `403`) is returned for resources owned by another user, so the API never
> leaks whether someone else's animal id exists.

### 6.7 Versioning policy

The version is in the path (`/api/v1`). Additive changes (new fields, new endpoints)
ship within v1. Anything that breaks a client (removed/renamed field, changed type or
status) goes in a future `/api/v2`; v1 keeps working until clients migrate.

### 6.8 Doctor invites & access (§4.3)

Farm-admin endpoints (behind auth + the paywall + `RequireFarmAdmin`):
| Method | Path                        | Body                            | Success | Errors |
|--------|-----------------------------|---------------------------------|---------|--------|
| POST   | `/api/v1/invites`           | `{doctorLabel, expiresAt?}`     | `201` Invite — the response carries the QR `token` | `403`, `422` |
| GET    | `/api/v1/invites`           | —                               | `200` List<Invite> — the farm's history, with each doctor's `noteCount` | `403` |
| POST   | `/api/v1/invites/{id}/end`  | —                               | `200` Invite — revokes access immediately | `403`, `404` |

Doctor entry point (**public** — a doctor has no account):
| Method | Path                       | Body      | Success | Errors |
|--------|----------------------------|-----------|---------|--------|
| POST   | `/api/v1/doctor/redeem`    | `{token}` | `200` DoctorSession | `401` unknown/ended/expired, `402` farm unpaid |

- `Invite`: `{id, doctorLabel, token, status, expiresAt, createdAt, endedAt, noteCount}`.
- `DoctorSession`: `{accessToken, tokenType, expiresAt, farm: {id, name}, doctorLabel}`.
- **Redeem doubles as the doctor's refresh.** The app keeps the invite secret and
  re-redeems it when the short-lived access token expires; once the invite is ended that
  re-redeem fails, which is how revocation reaches a phone that is already signed in.
- The doctor writes notes through the **same** notes endpoint (§6.5) — no separate
  "doctor notes" route. Authorization differs by principal, not by URL.
- Ending an invite **keeps its notes**; they stay in the animal's history under the
  `authorLabel` stamped at write time.

### 6.9 Farm members (§4.3)

Farm-admin endpoints, deliberately **outside** the paywall so a lapsed farm can still be
managed:
| Method | Path                          | Body                        | Success | Errors |
|--------|-------------------------------|-----------------------------|---------|--------|
| GET    | `/api/v1/farm/members`        | —                           | `200` List<Member> | `403` |
| POST   | `/api/v1/farm/members`        | `{phoneNumber, password}`   | `201` Member — creates the farmer's login | `403`, `409` phone taken, `422` |
| DELETE | `/api/v1/farm/members/{id}`   | —                           | `204` | `403`, `404` (also when the target is the admin) |

- `Member`: `{userId, phoneNumber, role, createdAt}`.
- One user belongs to **one** farm (`farm_members.user_id` is UNIQUE), so a phone that
  already exists anywhere is a `409`.
- The admin cannot be removed — the farm would be left with no one who can pay.

---

## 7. Subscription / billing design (InstaPay)

**The core constraint.** InstaPay gives an individual/small merchant **no API to
charge a card and no webhook to confirm receipt**. All you have is an **IPA** (e.g.
`yourname@instapay`) or a phone/wallet number that people transfer money to, plus the
**reference number** every transfer produces and whatever notification your **bank**
sends you (SMS/email/app). So activation can't be automatic from the gateway — it's
**user submits proof → admin confirms**. Below is that flow, plus an optional
semi-automation path if you can read your bank notifications.

### 7.1 Suggested pricing (EGP)

Charge per plan, with yearly discounted to push annual commitment. InstaPay transfers
inside Egypt are typically free/cheap for the sender, so you keep ~100% (no gateway fee).

| Plan    | Example price | Notes                                  |
|---------|---------------|----------------------------------------|
| Monthly | e.g. 150 EGP/mo | low commitment                       |
| Yearly  | e.g. 1500 EGP/yr | ~2 months free vs monthly; better LTV |

(Numbers are placeholders — set to your market. The mechanism is what matters.)
Plans/prices and **your IPA** live in env/config so you can change them without a deploy
to the client.

### 7.2 The paywall (subscription gate middleware)

After the auth middleware, a **subscription gate** runs on the protected resource
routes (`/api/v1/animals/**`, notes, invites). It checks the **caller's farm**:

```
allowed = now() < current_period_end   (i.e. status='active')
```

The gate keys off the **farm that owns the data**, not the individual caller: a visiting
doctor is never charged, but their call is allowed only while the farm that invited them
is paid up — so a lapsed farm locks the herd for everyone touching it.

If not allowed → respond `402` with the standard error envelope (§6.6)
`{ "error": { "code": "subscription_required", "message": "..." } }`. The app shows the
paywall/pay-by-InstaPay screen on `402`. **Do not** gate `/api/v1/auth/*`, `/api/v1/me`,
the billing endpoints, or `/api/v1/farm/members` (otherwise a lapsed admin could never
pay or fix their farm).

### 7.3 New endpoints (under `/api/v1`)

User endpoints (require auth):
| Method | Path                             | Purpose                                                   |
|--------|----------------------------------|-----------------------------------------------------------|
| GET    | `/api/v1/billing/status`         | Current plan + status + period end (for the UI)           |
| GET    | `/api/v1/billing/plans`          | Plans + EGP prices + **your IPA / pay-to handle**         |
| POST   | `/api/v1/billing/payments`       | User reports a transfer: `{plan, instapayRef, amountEgp, screenshotUrl?}` → creates a `pending` payment (`Idempotency-Key` recommended; `409` on reused `instapayRef`) |
| GET    | `/api/v1/billing/payments`       | List<Payment> — the user's own submissions + status       |

Admin endpoints (require auth **and** `isAdmin`):
| Method | Path                                       | Purpose                                       |
|--------|--------------------------------------------|-----------------------------------------------|
| GET    | `/api/v1/admin/payments?status=pending`    | Queue of payments awaiting review             |
| POST   | `/api/v1/admin/payments/{id}/confirm`      | Confirm → mark `confirmed`, extend subscription |
| POST   | `/api/v1/admin/payments/{id}/reject`       | Reject → mark `rejected` with a `note`        |

> These JSON admin endpoints back the **admin dashboard** (§8), which is a browser UI
> at `/admin/**` using cookie sessions. Same service layer, two transports.

### 7.4 Flow — InstaPay manual verify (primary)

1. App calls `GET /api/v1/billing/plans` → shows plans, EGP amount, and **your IPA**
   (`yourname@instapay`) with a copy button.
2. User opens their banking/InstaPay app and **transfers the amount** to your IPA.
   InstaPay shows them a **reference number** on success.
3. User returns to Raai and calls `POST /api/v1/billing/payments` with
   `{plan, instapayRef, amountEgp, screenshotUrl?}`. Backend inserts a `payments` row
   with `status='pending'` (`409` on duplicate `instapay_ref`). Optionally it also
   flips the user's subscription to `status='pending'` for UI ("under review").
4. **You (admin)** check the reference against money actually received in your bank /
   InstaPay history, then call `POST /api/v1/admin/payments/{id}/confirm`.
5. On confirm, the backend in **one transaction**:
   - sets the payment `confirmed`, `reviewed_by`, `reviewed_at`;
   - upserts the user's `subscriptions` row: `status='active'`, and extends
     `current_period_end` by the plan length (**+1 month** / **+1 year**) from
     `max(now(), current_period_end)` so early renewals stack instead of being lost.
6. App polls `GET /api/v1/billing/status` (or just retries the gated call) → paywall lifts.

> **Never grant access on the client's word alone.** The `pending` state gives the
> user feedback, but only an admin confirm (a human matching the reference to received
> money) moves `current_period_end`. This is the InstaPay equivalent of "the webhook
> is the source of truth."

### 7.5 Optional — assisted / semi-automated confirmation

Pure manual review is fine at low volume. To cut the human step as you grow, pick one:

- **Bank notification ingestion.** Most banks send an SMS/email/push per incoming
  InstaPay transfer with the **amount + reference**. Forward those to the backend (e.g.
  an Android "SMS-forwarder" on a dedicated phone, or an email-to-webhook) and
  **auto-match** the parsed reference/amount against `pending` payments → auto-confirm.
  Treat this as best-effort: anything unmatched still lands in the admin queue.
- **Merchant IPA / aggregator.** If you register as a merchant (e.g. via your bank's
  collection product, Paymob/Fawry, or a PSP that exposes InstaPay), you may get a real
  callback. If so, add a verified `POST /api/v1/billing/webhook/instapay` that does what
  step 7.4.5 does — **no other layer changes**, because activation is already centered
  on `current_period_end`.

### 7.6 Lifecycle handling

- **Renewal** → user pays again, submits a new reference, admin confirms →
  `current_period_end` extended from its current value (stacking). Access is seamless
  if they renew before expiry.
- **Expiry** → a periodic sweep (cron / on-read check) flips `status` to `expired`
  once `now() >= current_period_end`. The gate then returns `402`.
- **No auto-renew exists** — InstaPay is a push transfer, so there's nothing to cancel.
  "Cancel" = the user simply stops paying; access lapses at period end. Send an
  in-app/-notification reminder a few days before `current_period_end`.
- **Idempotency / fraud** → `instapay_ref` is UNIQUE, so the same transfer can't be
  claimed twice; admins reject mismatched amounts or unrecognized references with a `note`.

### Billing env vars
```
# InstaPay payee details shown to users (no secret API — this is just your handle)
INSTAPAY_IPA=yourname@instapay      # your InstaPay address / pay-to handle
INSTAPAY_DISPLAY_NAME=Your Name     # shown on the paywall for reassurance
# Pricing (EGP) — keep server-side so you can change without shipping the app
PRICE_MONTHLY_EGP=150
PRICE_YEARLY_EGP=1500
# Optional, only if you add bank-SMS/email ingestion (§7.5)
BANK_NOTIFY_SHARED_SECRET=
```

---

## 8. Admin dashboard

A small **server-rendered web dashboard**, served by the **same Go binary** under
`/admin`, where you log in from a browser and approve InstaPay payments. Server-rendered
HTML (Go `html/template`, optionally **htmx** for click-to-confirm without a JS build)
keeps the "lowest cost" promise: no separate frontend app, no extra host, templates and
CSS embedded via `go:embed`.

> Why a separate transport instead of just the JSON admin endpoints from §7.3? Same
> **service layer**, two front doors. The mobile app uses **JWT**; a browser dashboard
> wants **cookie sessions + CSRF + HTML**. Keep one `admin` service (confirm/reject/
> grant) and call it from both the JSON handlers and the dashboard handlers.

### 8.1 Auth (browser, separate from the mobile JWT)

- `GET /admin/login` → form; `POST /admin/login` → verify `phone_number` + bcrypt
  password, require `is_admin`, then set a **signed, httpOnly, Secure, SameSite=Lax
  session cookie** (short JWT or a server session id).
- `POST /admin/logout` clears it. Idle timeout (e.g. 30–60 min).
- **Every** `/admin/**` page checks the session **and** `is_admin`; non-admins get `403`.
- CSRF token on all state-changing forms. Rate-limit `/admin/login`. Dashboard cookie
  and mobile JWT are independent — leaking one doesn't grant the other.

### 8.2 Pages

| Path                          | Shows                                                                 |
|-------------------------------|----------------------------------------------------------------------|
| `/admin` (home)               | Counts: **pending payments**, active subscribers, expiring ≤7 days, revenue this month |
| `/admin/payments?status=pending` | Review queue: user (phone), plan, claimed amount, `instapay_ref`, screenshot link, submitted-at, **Confirm** / **Reject** buttons |
| `/admin/payments?status=all`  | Full history with filter by status                                   |
| `/admin/payments/{id}`        | One payment + the user's subscription state; confirm/reject with a note |
| `/admin/subscribers`          | Users + plan + status + `current_period_end`; search by phone        |
| `/admin/users/{id}`           | User detail + **manual grant / extend / revoke** (for off-band cash, refunds, comps) |

### 8.3 Actions (reuse the §7.4 service)

- **Confirm** (`POST /admin/payments/{id}/confirm`) → same one-transaction logic as
  §7.4.5: mark payment `confirmed`, extend `current_period_end` from
  `max(now(), current_period_end)`, write `admin_audit`.
- **Reject** (`POST /admin/payments/{id}/reject`) → mark `rejected` with a note,
  write `admin_audit`. (Optionally notify the user in-app.)
- **Manual grant / revoke** (`POST /admin/users/{id}/grant|revoke`) → directly adjust
  the subscription for cash-in-hand, comps, or refunds; always audited.

> Every mutating action records `admin_audit(admin_id, action, target_user, detail)`,
> so there's a trail of who approved which transfer. `payments.reviewed_by` already
> captures the per-payment reviewer.

### 8.4 Bootstrapping the first admin

Migrations can't know your user id, so seed it explicitly: a one-off
`UPDATE users SET is_admin = true WHERE phone_number = '...'` run as a deploy step, or a
tiny `make-admin` CLI subcommand on the binary (`./api admin grant <phone>`). Don't
expose "promote to admin" in the API.

---

## 9. Production deployment & containerization (lowest cost)

```
Go binary (static, ~10–20 MB image with distroless/scratch base)
  → Docker container (one image: serves API + admin dashboard)
  → Fly.io or Azure Container Apps  (scale-to-zero; ~$0–5/mo at low traffic)
  → Managed PostgreSQL (free tier → ~$0–7/mo)
  → TLS terminated at the platform
  → Migrations run as a separate one-shot container/job (not on app startup)
```

Add in middleware: structured logging, panic recovery, rate limiting, and a
`GET /healthz` (no-DB liveness) + `GET /readyz` (pings DB) for the platform's checks.
Because the dashboard's `web/templates` and `static` are **`go:embed`-ed into the
binary**, the image stays a single self-contained file — no asset volume to mount.

### 9.1 Production Dockerfile (multi-stage, cached, non-root)

```dockerfile
# ---- build ----
FROM golang:1.22 AS build
WORKDIR /src
# Cache deps separately from source so code edits don't re-download modules.
COPY go.mod go.sum ./
RUN go mod download
COPY . .
ARG VERSION=dev
RUN CGO_ENABLED=0 GOOS=linux go build \
      -trimpath -ldflags "-s -w -X main.version=${VERSION}" \
      -o /api ./cmd/api

# ---- runtime ----
FROM gcr.io/distroless/static-debian12:nonroot
# distroless:nonroot runs as uid 65532, no shell, no package manager → tiny attack surface.
COPY --from=build /api /api
EXPOSE 8080
USER nonroot:nonroot
ENTRYPOINT ["/api"]
```

Pair it with a `.dockerignore` so the build context stays small and no secrets leak in:

```
.git
*.md
Dockerfile
docker-compose.yml
.env
**/*_test.go
```

### 9.2 Migrations as a one-shot container (never on startup)

Build migrations into the same image (ship the `migrations/` dir + the
`golang-migrate` CLI, or add a `./api migrate up` subcommand to the binary). Run it as
a **discrete job before the app rolls out**, so it can't race across instances (§10.2):

- **Fly.io:** `release_command = "/api migrate up"` in `fly.toml` (runs once per deploy).
- **Container Apps / k8s:** an init/Job step that runs `migrate up` to completion first.
- **Compose / self-host:** a `migrate` service the `api` depends on (below).

### 9.3 Local / self-host with Docker Compose

For local dev or a cheap single-VPS deploy, one Compose file brings up Postgres, runs
migrations once, then starts the app:

```yaml
services:
  db:
    image: postgres:16-alpine
    environment:
      POSTGRES_USER: raai
      POSTGRES_PASSWORD: ${DB_PASSWORD}
      POSTGRES_DB: raai
    volumes: [pgdata:/var/lib/postgresql/data]
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U raai"]
      interval: 5s
      timeout: 3s
      retries: 5

  migrate:
    build: { context: ., args: { VERSION: "${VERSION:-dev}" } }
    command: ["/api", "migrate", "up"]
    environment:
      DB_CONNECTION_STRING: postgres://raai:${DB_PASSWORD}@db:5432/raai?sslmode=disable
    depends_on:
      db: { condition: service_healthy }
    restart: "no"

  api:
    build: { context: ., args: { VERSION: "${VERSION:-dev}" } }
    env_file: [.env]              # JWT_KEY, INSTAPAY_IPA, prices, etc. — never commit this
    environment:
      DB_CONNECTION_STRING: postgres://raai:${DB_PASSWORD}@db:5432/raai?sslmode=disable
    ports: ["8080:8080"]
    depends_on:
      migrate: { condition: service_completed_successfully }
    healthcheck:
      test: ["CMD", "/api", "healthcheck"]   # tiny subcommand that hits /healthz
      interval: 15s
      timeout: 3s
      retries: 3
    restart: unless-stopped

volumes:
  pgdata:
```

> distroless has **no shell**, so a `CMD-SHELL` healthcheck won't work in-container — add
> a tiny `healthcheck` subcommand to the binary (or let the hosting platform probe
> `/healthz` over HTTP, which is what Fly/Container Apps do anyway).

### 9.4 Config & secrets in containers

- All config via **env vars** (§5, §7) — 12-factor, no config files baked into the image.
- **Never** bake `JWT_KEY`, `DB_CONNECTION_STRING`, or `BANK_NOTIFY_SHARED_SECRET` into
  a layer. Inject at runtime: platform secrets (`fly secrets set`, Container Apps
  secrets) in prod; a git-ignored `.env` locally.
- Tag images immutably (`:gitsha`), not just `:latest`, so a rollback is a redeploy of
  a known tag.

---

## 10. Changes to make during the rewrite (don't copy these bugs)

1. **Hash passwords with bcrypt.** The current backend stores and compares
   **plaintext** passwords. In Go: `bcrypt.GenerateFromPassword` on signup,
   `bcrypt.CompareHashAndPassword` on signin. (One-time migration: rehash on next
   successful login, or force a reset.)
2. **Don't auto-migrate on startup.** The current app runs migrations on boot, which
   races across instances. Run `golang-migrate` as a discrete deploy/CI step.
3. (Already implied) Use **Postgres**, not SQL Server, to kill licensing cost.

---

## 11. Build order — as built

Steps 1–12 below are **done**; the numbering follows the order they were built in.

1. Project skeleton, config, pgx pool, `0001_init.sql` (users/animals/notes).
2. Auth: bcrypt + JWT issue/verify + middleware, `/api/v1/auth/*` + `/api/v1/me` (§6.2).
3. Animals + notes handlers/queries per the `/api/v1` contract (§6): error envelope,
   cursor pagination, notes nested under animal id.
4. `0002_roles_visits.sql` — the first pass at vet access, later replaced (see step 9).
5. `0003_subscriptions.sql` — `subscriptions` + `payments` + `admin_audit` + `users.is_admin`.
6. Billing endpoints: `GET /billing/plans`, `POST /billing/payments`,
   `GET /billing/status`, `GET /billing/payments`.
7. Admin **service** (confirm/reject/grant/revoke) + `is_admin`, extending
   `current_period_end` in one transaction and writing `admin_audit`.
8. **Admin dashboard** (§8): cookie login, pending-payments queue, confirm/reject,
   farms list, manual grant/revoke — same service as step 7.
9. `0004_farms.sql` + `0005_doctor_invites.sql` — the **farm tenant** model (§4.3):
   ownership moved from users to farms, `farm_members`, and **doctor invites replacing
   visits**. Notes now record `author_kind` / `author_label` instead of a visit id.
10. Subscription-gate middleware → `402` keyed off the **farm** (§7.2), plus the hourly
    expiry sweep.
11. Containerized (§9): multi-stage non-root Dockerfile, migrations as a one-shot job,
    Compose for local.
12. `0006_idempotency.sql` + the `Idempotency-Key` middleware (§6.1) — the replay
    guarantee the app's offline outbox depends on.

**Remaining (optional):** §7.5 bank-notification ingestion, to auto-confirm payments
instead of reviewing each one by hand. Everything else in this document is implemented.

### Test suite

The Go tests split in two. Pure unit tests (JWT, bcrypt, cursor pagination, the error
envelope, the rate limiter, config) need nothing. The integration tests drive the **real
HTTP handler against a real Postgres** and skip themselves unless `TEST_DATABASE_URL`
points at a database they may wipe:

```bash
docker compose up -d db
createdb raai_test   # or: psql -c 'CREATE DATABASE raai_test'
TEST_DATABASE_URL='postgres://raai:raai@localhost:5432/raai_test?sslmode=disable' \
  go test ./...
```

They cover the paths worth being sure about: farm isolation, the paywall gate, the
author-only note rules, doctor-invite redemption and revocation, and the money path
(submit → confirm → period extended → audited, and the double-confirm that must not buy
two months).
