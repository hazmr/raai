# Running Raai (راعي)

How to run the whole project locally: the **Go backend** (API + admin dashboard +
PostgreSQL) and the **Flutter app** (`app/`). The app talks to the backend over
`/api/v1` on **port 8080**.

```
Flutter app  ──HTTP──►  Go API (:8080/api/v1)  ──►  PostgreSQL
                         Go admin dashboard (:8080/admin)
```

> TL;DR: `cd server && docker compose up -d --build` to start the backend, then
> `cd app && flutter run` to start the app. Details and gotchas below.

---

## One-liners (copy/paste)

**Backend — start + create the admin only** (idempotent; admin = `01000000000` / `admin123`):
```bash
cd server && docker compose up -d --build && until curl -sf localhost:8080/healthz >/dev/null; do sleep 1; done && curl -s -X POST localhost:8080/api/v1/auth/register -H 'Content-Type: application/json' -d '{"phoneNumber":"01000000000","password":"admin123"}' >/dev/null; docker compose exec -T api /api admin grant 01000000000
```

**Run on a USB phone** (tunnels the backend to the device, then runs):
```bash
cd app && ~/Android/Sdk/platform-tools/adb reverse tcp:8080 tcp:8080 && flutter run --dart-define=API_BASE_URL=http://localhost:8080/api/v1
```

**Build a standalone APK** (points at this machine's LAN IP — phone must share the Wi‑Fi):
```bash
cd app && flutter build apk --release --dart-define=API_BASE_URL=http://$(ip route get 1 | awk '{print $7; exit}'):8080/api/v1
```
Output: `app/build/app/outputs/flutter-apk/app-release.apk`.

---

## 1. Backend (`server/`)

### Prerequisites
- **Docker** with the Compose plugin (this is all you need to *run* it — no Go required).
  ```bash
  docker --version
  docker compose version
  ```
- **Go 1.26+** only if you want to build natively or run the test suite (below).

### One-time configuration
```bash
cd server
cp .env.example .env       # if .env doesn't already exist
```
Open `.env` and set at least:

| Variable | What it is | Local value |
|----------|-----------|-------------|
| `JWT_KEY` | Secret that signs login tokens — make it long & random | `openssl rand -base64 48` |
| `SECURE_COOKIES` | `true` in production (HTTPS). **Set `false` for local** so the admin dashboard cookie works over `http://`. | `false` |
| `INSTAPAY_IPA` | Your InstaPay address shown on the paywall | `yourname@instapay` |
| `INSTAPAY_DISPLAY_NAME` | Name shown on the paywall | `Hazem Ahmed` |
| `PRICE_MONTHLY_EGP` / `PRICE_YEARLY_EGP` | Plan prices (EGP) | `150` / `1500` |

`DB_CONNECTION_STRING` is already correct for Docker — leave it. **Never commit `.env`.**

### Start it
```bash
cd server
docker compose up -d --build
```
This starts three things in order: **db** → **migrate** (one-shot, runs migrations to
completion) → **api**. Migrations never run on app startup — they're a discrete job.

### Verify it's up
```bash
docker compose ps                                   # api + db should be Up
curl -s -o /dev/null -w "%{http_code}\n" http://localhost:8080/healthz   # 200
curl -s -o /dev/null -w "%{http_code}\n" http://localhost:8080/readyz    # 200 (DB reachable)
```
Quick auth smoke test. Registering always creates a **farm** with the new user as its
admin; doctors never register (they redeem a QR invite instead):
```bash
# Register a farm admin → 201 with tokens
curl -s -X POST http://localhost:8080/api/v1/auth/register \
  -H 'Content-Type: application/json' \
  -d '{"phoneNumber":"01000000001","password":"secret123","farmName":"مزرعة النور"}'

# A password under 6 characters → 422 with per-field messages
curl -s -X POST http://localhost:8080/api/v1/auth/register \
  -H 'Content-Type: application/json' \
  -d '{"phoneNumber":"01000000009","password":"x"}'
```

### URLs
- API base: `http://localhost:8080/api/v1`
- Admin dashboard: `http://localhost:8080/admin`
- Health: `http://localhost:8080/healthz` · Readiness: `http://localhost:8080/readyz`

### Make yourself an admin (to use the dashboard)
Register/login once with your phone in the app or via curl, then grant admin:
```bash
docker compose exec api /api admin grant 01000000001
```
Now log in at `http://localhost:8080/admin` with that phone + password.

### Logs / stop / reset
```bash
docker compose logs -f api          # follow API logs
docker compose down                 # stop (keeps the database volume)
docker compose down -v              # stop AND wipe the database (fresh start)
```

### Run the tests
Unit tests (JWT, bcrypt, pagination, the error envelope, the rate limiter, config) need
nothing but Go:
```bash
cd server
make test            # go test ./...
```
The integration tests drive the **real HTTP handler against a real Postgres** and skip
themselves unless `TEST_DATABASE_URL` names a database they may wipe:
```bash
docker compose up -d db
docker compose exec -T db psql -U raai -c 'CREATE DATABASE raai_test'   # once
make test-integration
```
They cover farm isolation, the paywall gate, author-only note editing, doctor-invite
redemption and revocation, `Idempotency-Key` replay, and the money path (submit →
confirm → period extended → audited).

### Optional: run the backend without Docker (native Go)
Needs Go 1.26+ and a local Postgres. From `server/` (`make` loads `.env`):
```bash
make migrate-up      # build + run migrations
make run             # build + ./bin/api serve   (listens on $ADDR, default :8080)
make admin PHONE=01000000001
```
Point `DB_CONNECTION_STRING` in `.env` at your local Postgres (e.g.
`postgres://raai:raai@localhost:5432/raai?sslmode=disable`).

---

## 2. Flutter app (`app/`)

### Prerequisites
- **Flutter 3.47+** (stable) and an **Android device or emulator** — this is an
  Android-first app.
- **JDK 17–24** for the Gradle build (Gradle 8.14 does not run on JDK 25). Android
  Studio's bundled JDK 21 is the easy answer; point Flutter at it once with
  `flutter config --jdk-dir=<path>` if your system default is newer.
  ```bash
  flutter doctor
  flutter devices
  ```

### Install dependencies
```bash
cd app
flutter pub get
```
Localizations are generated automatically (`generate: true`); to do it manually:
`flutter gen-l10n`.

### Point the app at the backend
The API base URL is injected at build time (defaults to the Android emulator's host
alias `10.0.2.2:8080`). Override with `--dart-define=API_BASE_URL=...`:

| Where the app runs | Backend at | Use |
|--------------------|-----------|-----|
| **Android emulator** | host machine | default — nothing to pass (`http://10.0.2.2:8080/api/v1`) |
| **Physical phone over USB** (recommended) | host via `adb reverse` | `adb reverse tcp:8080 tcp:8080` once, then `--dart-define=API_BASE_URL=http://localhost:8080/api/v1` |
| **Physical phone over Wi-Fi** | your computer's LAN IP | `--dart-define=API_BASE_URL=http://192.168.1.X:8080/api/v1` |

`adb` lives in `~/Android/Sdk/platform-tools`. Find your LAN IP with `ip addr` (Linux) /
`ipconfig` (Windows) / `ifconfig` (macOS). The app's Android manifest already allows
cleartext HTTP, so plain `http://` works in dev.

### Run it
```bash
cd app

# Android emulator (uses the 10.0.2.2 default)
flutter run

# Physical device over USB — tunnel the backend to the phone first, then run
adb reverse tcp:8080 tcp:8080
flutter run --dart-define=API_BASE_URL=http://localhost:8080/api/v1

# Physical device over Wi-Fi — pass your computer's LAN IP instead
flutter run --dart-define=API_BASE_URL=http://192.168.1.X:8080/api/v1
```

> **Toolchain note.** The app currently builds against `compileSdk = 34` with the
> stock Flutter 3.22.1 Android toolchain (AGP 7.3.0 / Gradle 7.6.3). The offline-cache
> packages (`drift`, `sqlite3_flutter_libs`, etc.) are **deferred** in
> [`pubspec.yaml`](app/pubspec.yaml) because they require `compileSdk = 35`, which AGP
> 7.3.0's aapt2 can't link. When the offline engine (§7) is built, re-add those deps and
> bump **AGP 7→8 + Gradle 8 + Kotlin** together (JDK 17 required for the Gradle build).

### Build a release APK
```bash
flutter build apk --release \
  --dart-define=API_BASE_URL=http://YOUR_BACKEND_HOST:8080/api/v1
# output: build/app/outputs/flutter-apk/app-release.apk
```

### Checks (no device needed)
```bash
flutter analyze     # static analysis — should be clean
flutter test        # offline engine (repository + outbox) and the boot smoke test
```

The offline tests run against a real in-memory SQLite, so they need no device and no
backend. If you change the drift tables in `lib/core/db/app_database.dart`, regenerate
the database code:
```bash
dart run build_runner build --delete-conflicting-outputs
```

---

## 3. Try the full flow

1. Start the backend (`docker compose up -d --build`).
2. Run the app on an emulator (`flutter run`).
3. **Register** (creates a **farmer / راعي** account — vets can't self-register).
4. Add an animal (or Scan → enter a tag → "Add"), open it, add a note.
5. Hit the **Subscription** tile → paywall: copy the InstaPay address, paste any
   reference, submit → **"Under review"**.
6. In the browser, open `http://localhost:8080/admin` (as an admin), find the pending
   payment, and **Confirm** it → the app's paywall lifts on the next status poll.

> **Doctors never sign up.** The farm admin creates an invite (Doctors tile → new
> doctor visit), the app shows it as a **QR code**, and the vet scans it from the app's
> `/doctor` entry screen to get a session scoped to that farm. "End access" revokes it
> on their next request; the notes they wrote stay in the animal's history.

### Try it offline

1. With the app open on the herd, turn on **airplane mode**.
2. Scan or add an ear tag, then open it and write a note — both save instantly and show
   **"not sent yet"**, and a banner reports how many changes are waiting.
3. Turn airplane mode off. The queue drains on its own (or tap **Send now**), the marks
   clear, and the notes pick up the server's authorship.

---

## Notes & current limitations

- **Camera QR/barcode scanning** is wired (`mobile_scanner 7.x`). The Scan screen reads
  an ear-tag QR — the payload is the plain tag number produced by `qr_grid.py` — and
  runs lookup-or-create against the **local cache**, so it works with no signal. A
  keyboard button still allows manual entry. Grant the camera permission on first use.
- **Voice notes** (`speech_to_text`) are wired into the add-note sheet; the mic button
  dictates into the field (Arabic first). Grant the microphone permission on first use.
- **Offline capture** (drift/SQLite + outbox) is wired: the herd, its notes and the
  pending-write queue live on the phone, and queued writes replay with an
  `Idempotency-Key` so a retry can't double-create. See `FLUTTER_APP_DESIGN.md` §7.
- The app targets **Android**; desktop/iOS targets aren't set up.

### Printing ear-tag QR sheets (`qr_grid.py`)
`qr_grid.py` (repo root) generates a print-ready PDF grid of sequentially-numbered QR
codes for the ear tags the app scans:
```bash
pip install segno reportlab
python qr_grid.py --start 1 --count 100 -o qr_codes.pdf
```
Each QR encodes the number (optionally zero-padded with `--digits`); that number is what
the Scan screen reads as the animal's `barcode`.
