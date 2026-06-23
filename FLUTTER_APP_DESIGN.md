# Raai (راعي) — Flutter App Design

The mobile app for **Raai**, the livestock notes app. Talks to the Go backend's
**`/api/v1`** contract (see `SYSTEM_DESIGN.md`). Two roles share one app:
**farmer** (owns the herd, pays) and **vet** (a visitor who writes notes inside a visit).

> **Design north star:** *as simple as possible.* A farmer in a field should finish the
> common task in 1–2 taps. Big targets, few screens, plain language, works offline,
> **Arabic-first (RTL)**.

---

## 1. Design language

A **hybrid**, chosen for simplicity:

- **Home = Bento Box.** A grid of large, rounded tiles of varying size — each a single
  job (Herd, Scan, Visit, Subscription). Glanceable, enormous touch targets, no menus
  to learn. This is the *only* "designed" screen.
- **Everywhere else = Utilitarian.** Plain lists, plain forms, one action per screen,
  high contrast, no decoration. Function over polish.

### 1.1 Tokens (keep the whole system this small)

| Token        | Value                                                        |
|--------------|--------------------------------------------------------------|
| Spacing      | `4, 8, 12, 16, 24` (nothing else)                            |
| Radius       | `16` bento tiles · `12` buttons/inputs                       |
| Touch target | **min 56 dp** (field use, gloves)                            |
| Primary      | pasture green `#2E7D32`                                       |
| Surface / bg | `#FFFFFF` / `#F4F5F3` (warm neutral)                         |
| Text         | `#1B1B1B` primary · `#5F6360` secondary                      |
| Semantic     | success `#2E7D32` · warning `#B26A00` · error `#C62828`      |
| Font         | **Cairo** (great Arabic + Latin); system fallback            |
| Type scale   | display 28 · title 20 · body 16 · label 13 (all ≥16 for input)|

> One accent color, one font, a 5-step spacing scale. If a screen needs more than this,
> it's too complex — cut it.

### 1.2 Bento home sketch (farmer)

```
┌──────────────────────────────────┐
│  راعي                  🔔   ☰    │
│  أهلاً يا أحمد                     │
├─────────────────┬────────────────┤
│                 │   📷  مسح       │
│   🐄  القطيع    │   Scan tag     │
│   128 رأس       ├────────────────┤
│   (tall tile)   │   ➕  زيارة     │
│                 │   New visit    │
├─────────────────┴────────────────┤
│  ✅  الاشتراك فعّال                │
│  يتجدد ١٢ يوليو      →             │
└──────────────────────────────────┘
```

Vet home is the same grid with two tiles: **الزيارات المفتوحة / Open visits** (big) and
**مسح / Scan**.

---

## 2. Tech stack (minimal on purpose)

| Concern        | Choice                  | Why                                            |
|----------------|-------------------------|------------------------------------------------|
| Framework      | Flutter (stable)        | One codebase, Android first                     |
| State          | **Riverpod**            | Simple, testable; use plain `setState` for trivial screens |
| Navigation     | **go_router**           | Declarative routes + redirect (auth/paywall)    |
| HTTP           | **dio**                 | Interceptors for JWT attach + 401 refresh       |
| Token storage  | **flutter_secure_storage** | Keep access/refresh tokens off plain prefs   |
| Local cache    | **drift** (SQLite)      | Offline herd + outbox queue; type-safe SQL      |
| Barcode        | **mobile_scanner**      | Ear-tag scanning                                |
| Voice notes    | **speech_to_text**      | Dictate a note hands-free                       |
| i18n / RTL     | `flutter_localizations` + `intl` | Arabic default, English optional       |

That's the entire dependency list. Resist adding more.

---

## 3. Project structure

```
lib/
  main.dart                 # app, theme, localization, router
  core/
    theme.dart              # the §1.1 tokens, one ThemeData
    api/
      dio_client.dart       # base url, JWT interceptor, 401→refresh
      api.dart              # thin typed wrappers over /api/v1
    db/                     # drift: cached animals + outbox (offline notes)
    auth/                   # token store, session state (role: farmer|vet)
  features/
    auth/                   # login, register (pick role)
    home/                   # bento home (farmer vs vet)
    animals/               # list, detail (notes timeline), add/edit
    scan/                   # barcode → lookup or create
    notes/                  # add note: templates + voice; offline outbox
    visits/                 # farmer: open/close; vet: open visits + animals
    billing/                # paywall, submit InstaPay ref, status
  l10n/                     # ar.arb (default), en.arb
```

---

## 4. Navigation & access

`go_router` with a single **redirect** guard:

- No tokens → `/login`.
- Logged in → home for the **role** (`/home` renders farmer or vet bento).
- Any screen returns **HTTP 402** → redirect to `/paywall` (farmer) — see §5.7.
- Vet has **no** billing/herd-management routes; farmer has **no** vet-visit inbox.

Routes (flat, few):
```
/login  /register
/home
/animals  /animals/:id  /animals/new
/scan
/visits  /visits/:id            (farmer opens; vet sees open ones)
/paywall                         (farmer only)
```

---

## 5. Screens (each mapped to the API)

### 5.1 Auth — `features/auth`
- **Login**: phone + password → `POST /api/v1/auth/login` → store tokens → `/home`.
- **Register**: phone + password + **role toggle (Farmer / Vet)** →
  `POST /api/v1/auth/register`. One screen, three fields.
- Tokens in secure storage; dio attaches `Authorization: Bearer`; on `401` the
  interceptor calls `POST /api/v1/auth/refresh` once, else bounce to login.

### 5.2 Home (bento) — `features/home`
- **Farmer** tiles → Herd (`GET /api/v1/animals`, shows count), Scan, New Visit,
  Subscription (`GET /api/v1/billing/status`, color = active/expiring/lapsed).
- **Vet** tiles → Open Visits (`GET /api/v1/visits?status=open`), Scan.

### 5.3 Herd & animal detail — `features/animals`
- **List**: `GET /api/v1/animals` (cursor pagination, infinite scroll). Search box →
  `?barcode=`. Plain list rows: tag + note count.
- **Detail**: animal header + **notes timeline** (`GET /api/v1/animals/{id}/notes`,
  newest first). A vet's note is **badged** (`authorRole=vet`). FAB → add note.
- **Add/Edit animal**: one field (`barcode`) → `POST` / `PATCH /api/v1/animals/{id}`.
  `409` → "this tag already exists" inline.

### 5.4 Scan — `features/scan`
- `mobile_scanner` full-screen. On read → `GET /api/v1/animals?barcode=` →
  - found → open animal detail;
  - not found → "Add this animal?" → `POST /api/v1/animals`.
- For a **vet**, scan happens *inside an open visit* so notes attach to it (§5.6).

### 5.5 Add note (the field-friendly part) — `features/notes`
One bottom sheet, three ways to fill `body`, **as simple as possible**:
1. **Quick templates** — chips: vaccination · checkup · treatment · birth → prefill text.
2. **Voice** — mic button (`speech_to_text`) dictates into the field.
3. **Type** — plain multiline.

Submit → `POST /api/v1/animals/{animalId}/notes` with `{body, visitId?}` +
`Idempotency-Key`. **Offline:** write to the drift **outbox** and show the note
immediately ("syncing…"); a background sync flushes when online (idempotency key makes
retries safe). Vet notes always include the open `visitId`.

### 5.6 Visits — `features/visits`
- **Farmer**: "New visit" → choose **clinic / farm** + label, enter **vet phone** (or
  pick from *my vets*) → `POST /api/v1/visits`. Then "Close visit" →
  `POST /api/v1/visits/{id}/close`. History via `GET /api/v1/visits`.
- **Vet**: home shows **open visits** (`?status=open`); tapping one →
  `GET /api/v1/visits/{id}/animals` to scan/look up, then add notes (§5.5). When the
  farmer closes it, write access ends — the app reflects it on next load.

### 5.7 Paywall — `features/billing` (farmer only)
Triggered by any `402` or the Subscription tile when lapsed:
1. `GET /api/v1/billing/plans` → show Monthly / Yearly (EGP) + **your IPA** with a big
   **Copy** button + step text: "Send the amount on InstaPay, then paste the reference."
2. Field: paste **reference** (+ optional screenshot) → `POST /api/v1/billing/payments`
   (`Idempotency-Key`). Show **"Under review"** state.
3. Poll `GET /api/v1/billing/status`; when `active`, dismiss the paywall.

> Admin review/confirm is **not** in the app — it's the web dashboard (`SYSTEM_DESIGN.md`
> §8). The app only submits and waits.

---

## 6. Error handling

**Principle:** the user sees **one short, friendly, localized sentence** with a clear
next step — **never** the raw server `message`, never a `code`, never a stack trace. The
real `error.code` + server `message` + request id go to **logs / Crashlytics** for you;
the human just gets "what happened" and "what to do."

### 6.1 One funnel
Every call goes through dio and produces a single **`ApiException`**:
- connection/timeout/no-network → `kind = offline`;
- non-2xx carrying the standard envelope `{ error: { code, message } }` → keep `code` + status.

UI never reads dio directly. It catches `ApiException` and asks an **`errorText(code)`**
mapper (backed by l10n) what to show. The server `message` is logged, not displayed.

### 6.2 Code → message → where it shows

| Backend (`SYSTEM_DESIGN.md` §6.6) | User sees (Arabic-first, also English) | Presentation |
|-----------------------------------|----------------------------------------|--------------|
| *offline / timeout*               | "لا يوجد اتصال — حاول مرة أخرى" / "No connection — try again" | banner/full-screen **Retry**; reads fall back to cache |
| `401 unauthorized`                | *(silent)* refresh once; if it fails → "انتهت الجلسة" + go to login | auto |
| `402 subscription_required`       | *(not an error)* → open paywall (§5.7) | auto route |
| `403 forbidden`                   | "لا تملك صلاحية لهذا الإجراء" / "You don't have access" | snackbar (e.g. vet on a closed visit) |
| `404 not_found`                   | contextual: "لم يتم العثور على هذا الحيوان" / "Animal not found" | inline/empty-state |
| `409 conflict`                    | contextual: tag → "هذا الرقم مسجّل بالفعل"; receipt → "هذا الإيصال مُستخدم من قبل" | **inline** on the field |
| `422 validation_error`            | use `fields` → message under each input; fallback "تحقق من البيانات" | **inline** under field |
| `429 rate_limited`                | "محاولات كثيرة — انتظر قليلًا" / "Too many tries — wait a moment" | snackbar |
| `400` / `500` / **unknown code**  | "حدث خطأ ما — حاول لاحقًا" / "Something went wrong — try later" | snackbar/full-screen **Retry** |

### 6.3 Four ways to surface it (pick by severity)
- **Inline (under the field)** — `422` validation, `409` conflicts on a form. Most specific, least disruptive.
- **Snackbar / toast** — a single action failed (e.g. a note didn't send) with **Retry** or "will retry when online."
- **Full-screen state** — a screen can't load at all: friendly icon + one line + **Retry**; for reads, show **cached** data instead when we have it.
- **Silent / automatic** — `401` (refresh), `402` (route to paywall), offline writes (queued to outbox, optimistic UI — see §7). No scary popups.

### 6.4 Rules
- **Map every code.** Anything unmapped falls to the one generic "something went wrong" —
  the server string is *never* shown.
- All messages live in `l10n/ar.arb` / `en.arb` (§8) — no hardcoded text.
- **Offline is not error spam:** reads use cache, writes queue silently (§7). Only show a
  network message when the user is actively waiting on something that needs the network.
- Log `code` + server `message` + request id; display none of it.

---

## 7. Offline & sync

The barn has no signal. Reads come from cache; writes queue and flush later. Keep the
model small — but get the two hard parts right (dependencies in §7.3, permanent failures
in §7.5).

### 7.1 What works offline (scope)

| Area | Offline? | How |
|------|----------|-----|
| View herd / animal / notes | ✅ read | served from the drift cache; refreshes when online |
| Add note | ✅ write | optimistic + queued in the **outbox** |
| Add animal (scan a new tag) | ✅ write | optimistic + queued; gets a **temp id** (§7.3) |
| Login / refresh, billing, open/close visit | ❌ online-only | need the server; show the §6 offline message if attempted |

> A vet can only queue notes for a visit that was opened **while online** (the `visitId`
> must already exist). Opening a visit is online-only.

### 7.2 The outbox

One drift table is the whole write-sync engine:

```
outbox(
  id            -- local autoincrement = flush order (oldest first)
  op            -- 'create_animal' | 'create_note'
  payload       -- JSON body
  idempotencyKey-- uuid v4, generated ONCE, reused on every retry
  status        -- pending | syncing | failed
  attempts      -- for backoff
  lastError     -- mapped §6 code if it failed
  createdAt
)
```

- The **`idempotencyKey`** is generated when the row is created and **never changes**, so
  a retry after a flaky response can't double-create (`SYSTEM_DESIGN.md` §6.1).
- Flush **oldest-first, one at a time**; on success delete the row and reconcile the local
  cache with the server response (real ids, timestamps).

### 7.3 Dependencies & temp ids (the scan→create→note chain)

Common offline flow: scan an unknown tag → create the animal → write a note on it — all
before the server has ever seen that animal. Handle it with **local temp ids**:

1. New animal gets a client `tempId` (e.g. `local:<uuid>`); it shows in the herd
   immediately. A `create_animal` row goes in the outbox.
2. A note on it queues a `create_note` row referencing that **`tempId`**.
3. On flush, `create_animal` runs first; its real server `id` is mapped
   `tempId → realId`, and any queued rows referencing `tempId` are **rewritten** to the
   real id before they flush.
4. If the animal create fails permanently (§7.5), its dependent notes are held back and
   flagged too — never sent against a non-existent parent.

### 7.4 When sync runs

Triggers, all cheap: **connectivity regained** (listener), **app foreground/resume**,
**pull-to-refresh**, and a light retry timer with **exponential backoff** for `failed`
rows. No background isolates needed for v1 — sync while the app is open is enough.

### 7.5 Conflicts & permanent failures

- **Notes are append-only** → effectively no merge conflicts; two devices just add two
  notes. Animals are keyed by `(barcode, owner)`, so the same tag created twice offline
  → the second flush gets **`409`** and we **merge to the existing animal** (drop the dup,
  remap its notes), not an error to the user.
- **Distinguish retryable vs permanent** when a flush fails:
  - *Retryable* (offline, timeout, `429`, `5xx`) → keep `pending`, back off, try again.
  - *Permanent* (`422` validation, `403` visit closed, unresolved `409`) → mark **`failed`**,
    stop auto-retrying, and surface it (§6) as a **"couldn't save — needs attention"**
    item the user can fix or discard. Never silently drop a write.

### 7.6 What the user sees

Optimistic everywhere: a queued note/animal appears instantly with a small **"⏳ syncing"**
badge → **"✓ saved"** on success → **"⚠ needs attention"** on permanent failure (tap to
retry/edit/discard). The list never blocks on the network.

> **Cache hygiene:** bound the cache (e.g. recent N animals + their notes); evict
> least-recently-viewed. Don't try to mirror the entire herd of a 10,000-head farm.

---

## 8. Localization & RTL

- **Arabic is the default locale**, English optional. `Directionality` flips with the
  locale; the bento grid and lists mirror automatically.
- All strings in `l10n/ar.arb` / `en.arb` — no hardcoded text.
- Cairo font for clean Arabic numerals/letters; format dates/numbers with `intl` using
  the active locale.

---

## 9. Build / run

```
flutter pub get
flutter run                       # against a local backend
flutter build apk --release       # Android release
```
Point the base URL at the backend via `--dart-define=API_BASE_URL=...` so dev/prod
differ without code changes (mirrors the backend's env-first config).

---

## 10. Build order (suggested)

1. Theme + tokens (§1.1), Cairo font, Arabic/English l10n + RTL scaffold.
2. dio client + secure token store + 401-refresh interceptor + the `ApiException`
   funnel and `errorText(code)` mapper (§6); login/register (role).
3. go_router + redirect guard (auth → home, 402 → paywall).
4. Bento home (farmer + vet variants).
5. Herd list + animal detail (notes timeline) + add/edit animal.
6. Scan (mobile_scanner) → lookup/create.
7. Add-note sheet: templates + voice; then the drift **outbox** + offline sync.
8. Visits: farmer open/close, vet open-visits + visit animals.
9. Paywall: plans + IPA copy + submit reference + status polling.
10. Polish: empty states, friendly errors via the §6 mapper (inline/snackbar/full-screen),
    loading skeletons.
