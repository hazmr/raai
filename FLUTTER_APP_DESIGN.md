# Raai (راعي) — Flutter App Design

The mobile app for **Raai**, the livestock notes app. Talks to the Go backend's
**`/api/v1`** contract (see `SYSTEM_DESIGN.md`). Two roles share one app:
**farm members** (an admin who pays, plus the farmers working with them) and **visiting
doctors**, who get in by scanning a revocable QR invite rather than holding an account.

> **Design north star:** *as simple as possible.* A farmer in a field should finish the
> common task in 1–2 taps. Big targets, few screens, plain language, works offline,
> **Arabic-first (RTL)**.

---

## 1. Design language

A **hybrid**, chosen for simplicity:

- **Home = Bento Box.** A grid of large, rounded tiles of varying size — each a single
  job (Herd, Scan, Doctors, Farmers, Subscription). Glanceable, enormous touch targets, no menus
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

### 1.2 Bento home sketch (farm admin)

```
┌──────────────────────────────────┐
│  مزرعة النور                      │
├─────────────────┬────────────────┤
│                 │   📷  مسح       │
│   🐄  القطيع    │   Scan tag     │
│   128 رأس       ├────────────────┤
│   (tall tile)   │  🩺  الأطباء    │
│                 │   Doctors      │
├─────────────────┴────────────────┤
│  👥  المزارعون / Farmers          │
├──────────────────────────────────┤
│  ✅  الاشتراك فعّال                │
│  يتجدد ١٢ يوليو      →             │
└──────────────────────────────────┘
```

A **member** or an invited **doctor** sees the same grid reduced to two tiles:
**القطيع / Herd** (big) and **مسح / Scan** — no billing, no farm management.

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
    db/                     # drift: cached animals + notes + the outbox (§7)
    repo/                   # herd repository: local-first reads, queued writes
    sync/                   # outbox drain + connectivity trigger + providers
    auth/                   # token store, session state (member | doctor)
    widgets/                # shared states + the sync banner
  features/
    auth/                   # login, register, doctor QR redeem
    home/                   # bento home (admin vs member/doctor)
    animals/                # list, detail (notes timeline), add
    scan/                   # ear tag → local lookup or create
    notes/                  # add note: templates + voice + offline outbox
    invites/                # admin: create/end doctor invites, show the QR
    farm/                   # admin: farm members
    billing/                # paywall, submit InstaPay ref, status
  l10n/                     # ar.arb (default), en.arb
```

---

## 4. Navigation & access

`go_router` with a single **redirect** guard:

- No tokens → `/login` (or `/doctor`, where a vet scans their invite QR).
- Logged in → `/home`, which renders the admin bento or the simpler member/doctor one.
- Any screen returns **HTTP 402** → redirect the **admin** to `/paywall` — see §5.7.
- Members and doctors have **no** billing, member or invite routes; the guard sends them
  back to `/home` rather than showing a screen they can't use.

Routes (flat, few):
```
/login  /register  /doctor
/home
/animals  /animals/:localId  /animals/new
/scan
/members  /invites                (farm admin only)
/paywall                          (farm admin only)
```

> `:localId` is the animal's **local** database id, not its server id — an ear tag
> registered with no signal has no server id yet and still has to be openable (§7).

---

## 5. Screens (each mapped to the API)

### 5.1 Auth — `features/auth`
- **Login**: phone + password → `POST /api/v1/auth/login` → store tokens → `/home`.
- **Register**: phone + password + **role toggle (Farmer / Vet)** →
  `POST /api/v1/auth/register`. One screen, three fields.
- Tokens in secure storage; dio attaches `Authorization: Bearer`; on `401` the
  interceptor calls `POST /api/v1/auth/refresh` once, else bounce to login.

### 5.2 Home (bento) — `features/home`
- **Admin** tiles → Herd (count read from the local cache), Scan, Doctor visits,
  Farmers, Subscription (`GET /api/v1/billing/status`, color = active/pending/lapsed).
- **Member / doctor** tiles → Herd, Scan.

### 5.3 Herd & animal detail — `features/animals`
- **List**: watched straight from the drift cache, so it renders with no signal. The
  search box filters locally by ear tag; pull-to-refresh drains the outbox and then
  pulls from `GET /api/v1/animals`. Rows: tag + note count, plus a "not sent yet" mark
  on anything still queued.
- **Detail**: animal header + **notes timeline**, also watched from the cache, newest
  first. A doctor's note is **badged** (`authorKind=doctor`) and shows the `authorLabel`
  stamped when it was written. FAB → add note.
- **Add animal**: one field (`barcode`) → written locally and queued (§7). A tag already
  in the herd is reported inline rather than duplicated.

### 5.4 Scan — `features/scan`
- `mobile_scanner` full-screen, with a consensus check: the same numeric tag must decode
  over several consecutive frames *and* persist briefly before it is accepted, and two
  tags in view refuse to lock at all.
- The lookup then runs **against the local cache** — scanning is the one thing that
  absolutely must work in a barn with no signal:
  - found → open animal detail;
  - not found → "Add this animal?" → the offline-safe create above.

### 5.5 Add note (the field-friendly part) — `features/notes`
One bottom sheet, three ways to fill `body`, **as simple as possible**:
1. **Quick templates** — chips: vaccination · checkup · treatment · birth → prefill text.
2. **Voice** — mic button (`speech_to_text`) dictates into the field.
3. **Type** — plain multiline.

Submit **always writes locally first** and queues the note (§7), so saving never
depends on signal: the note appears in the timeline at once, marked "not sent yet", and
the outbox delivers it with its `Idempotency-Key` when the connection returns. The
client sends only `{body}` — authorship comes from the token, server-side.

### 5.6 Doctor invites & farm members — `features/invites`, `features/farm`
- **Invites (admin)**: "New doctor visit" → doctor's name → `POST /api/v1/invites`,
  then render the returned `token` as a **QR** (`qr_flutter`) for the vet to scan.
  History lists each invite with how many notes that doctor wrote; "End access" →
  `POST /api/v1/invites/{id}/end` revokes on the doctor's next request.
- **Doctor side**: `/doctor` opens the scanner; scanning the QR calls
  `POST /api/v1/doctor/redeem` and yields a farm-scoped session with no account. The app
  keeps the invite secret and re-redeems it when the access token expires — which is
  also how revocation reaches an already-signed-in phone.
- **Members (admin)**: list, add a farmer (phone + starting password), remove one —
  `/api/v1/farm/members`. Reachable even when the subscription has lapsed.

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
| `403 forbidden`                   | "لا تملك صلاحية لهذا الإجراء" / "You don't have access" | snackbar (e.g. a doctor trying to edit an animal) |
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

## 7. Offline & sync — as built

The barn has no signal. Reads come from SQLite; writes go into an outbox and are
replayed when the connection returns.

### 7.1 What works offline

| Area | Offline? | How |
|------|----------|-----|
| View herd / animal / notes | ✅ read | watched from the drift cache; refreshed when online |
| Search the herd by ear tag | ✅ read | `LIKE` over the cached rows |
| Scan an ear tag | ✅ read | the lookup is local (§5.4) |
| Add a note | ✅ write | written locally, queued in the **outbox** |
| Register a scanned tag | ✅ write | written locally with a local id, queued |
| Login / refresh, billing, invites, members | ❌ online-only | they need the server; the §6 offline message is shown |

### 7.2 The three tables

`cached_animals` and `cached_notes` hold what the UI reads. Both carry a
`serverId` that is **null until the write lands** and a `pending` flag that drives the
"not sent yet" marks.

```
outbox_entries(
  id              -- autoincrement = replay order (oldest first)
  kind            -- 'createAnimal' | 'createNote'
  idempotencyKey  -- uuid v4, minted ONCE, reused on every retry
  targetLocalId   -- the local row this write creates
  animalLocalId   -- for a note: which animal it belongs to
  payload         -- JSON body
  attempts, lastError
  failed          -- parked: the server refused for a reason a retry won't fix
  createdAt
)
```

- The **`idempotencyKey`** never changes, so a replay after a dropped response is
  answered with the original result instead of creating a second row
  (`SYSTEM_DESIGN.md` §6.1 — implemented server-side).
- Entries replay **oldest-first, one at a time**; on success the local row takes the
  server's id and authorship, and the entry is deleted.

### 7.3 The scan → create → note chain

The common offline flow is: scan an unknown tag → register it → write a note on it, all
before the server has seen any of it. Two things make it work:

1. **Local ids are the app's ids.** Rows are keyed by an autoincrement `localId` and the
   router navigates by it, so an animal with no `serverId` is a first-class citizen —
   there is no "temp id" to rewrite later.
2. **A note waits for its animal.** Because entries replay in order, the animal is sent
   first and its `serverId` filled in. If the animal has not synced (its own entry was
   parked, say), the note is *skipped, not failed* — it goes out on a later pass.

### 7.4 When sync runs

**Connectivity regained** (a `connectivity_plus` listener), **session start**, after
**each queued write**, and on **pull-to-refresh**. Overlapping triggers share one pass,
so a reconnect during a manual refresh can't double-send. No background isolate: syncing
while the app is open is enough for v1.

### 7.5 Conflicts & permanent failures

- **Notes are append-only**, so two devices simply add two notes — no merge.
- **The same ear tag registered twice** (two farmers scanned the same new cow) is a
  `409` on replay: the app then looks the tag up on the server and **adopts** that
  animal's id, rather than surfacing an error or leaving a duplicate.
- Failures are classified rather than blindly retried:
  - *Retryable* — offline, `408`, `429`, `5xx` → the queue is kept and retried later.
  - *Blocking* — `401` (session ended) or `402` (farm lapsed) → the drain **stops**
    without marking anything failed; those writes go through once the user signs in
    again or the farm pays.
  - *Permanent* — anything else (e.g. `422`) → the entry is **parked**: flagged
    `failed`, skipped so it stops blocking the queue, and surfaced with a Retry. A write
    is never silently dropped.

### 7.6 What the user sees

A queued note or animal appears instantly, marked **"not sent yet"**. A thin banner
appears only while the outbox is non-empty — "N changes waiting to send", with **Send
now** — and turns into "N changes couldn't be sent" with **Retry** if anything was
parked. Nothing in the herd blocks on the network.

> **Cache hygiene:** a refresh walks up to 20 pages (1,000 animals) and then prunes
> synced rows the server no longer has, never touching rows still waiting to be sent.
> A very large herd would want a bounded, least-recently-viewed cache instead.

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

## 10. Build order — as built

1. Theme + tokens (§1.1), Arabic/English l10n + RTL scaffold.
2. dio client + secure token store + 401-refresh interceptor + the `ApiException`
   funnel and `errorText(code)` mapper (§6); login/register.
3. go_router + redirect guard (auth → home, 402 → paywall, admin-only routes).
4. Bento home (admin + member/doctor variants).
5. Herd list + animal detail (notes timeline) + add animal.
6. Scan (`mobile_scanner`) → lookup/create, with the consensus check (§5.4).
7. Doctor invites + QR redeem (§5.6) and farm members.
8. Paywall: plans + IPA copy + submit reference + status (§5.7).
9. **Offline engine (§7):** drift cache, outbox with idempotency keys, connectivity-
   triggered sync, and the screens rewritten to read local-first.
10. **Voice notes** — dictation in the add-note sheet (§5.5).
11. Polish: empty states, friendly errors via the §6 mapper, the sync banner.

Everything above is implemented. The Android toolchain moved with step 9: AGP 8.13 /
Gradle 8.14 / Kotlin 2.4 / Java 17, which is what `drift`'s `sqlite3_flutter_libs`,
`mobile_scanner` 7.x, `connectivity_plus` and `speech_to_text` require.

### Tests

`flutter test` covers the offline engine against a real in-memory SQLite — the
repository (local writes, queueing, refresh reconciliation, cache clearing on logout)
and the outbox (delivery order, offline queue retention, key reuse across retries, `409`
adoption, blocking vs permanent failures, parked-write retry).
