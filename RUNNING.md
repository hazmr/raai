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
- **Docker** with the Compose plugin (this is all you need — no Go required).
  ```bash
  docker --version
  docker compose version
  ```

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
Quick auth smoke test (registration is **farmer-only**; a vet role is rejected):
```bash
# Register a farmer → 201 with tokens
curl -s -X POST http://localhost:8080/api/v1/auth/register \
  -H 'Content-Type: application/json' \
  -d '{"phoneNumber":"01000000001","password":"secret123"}'

# Trying to register a vet → 422 "vets cannot self-register"
curl -s -X POST http://localhost:8080/api/v1/auth/register \
  -H 'Content-Type: application/json' \
  -d '{"phoneNumber":"01000000009","password":"x","role":"vet"}'
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

### Optional: run the backend without Docker (native Go)
Needs Go 1.22+ and a local Postgres. From `server/` (`make` loads `.env`):
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
- **Flutter** (stable) and an **Android device or emulator** — this is an Android-first
  app. Check your setup:
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
flutter test        # boot smoke test
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

> **Vet accounts** are provisioned by an admin (not through sign-up). A farmer opens a
> **visit** with the vet's phone to grant time-boxed write access to their herd.

---

## Notes & current limitations

- **Camera QR/barcode scanning** is wired (`mobile_scanner 3.5.x`, Kotlin bumped to
  1.8.22). The Scan screen reads an ear-tag QR — the QR payload is the plain tag number
  produced by `qr_grid.py` — and runs lookup-or-create; a keyboard button still allows
  manual entry. Grant the camera permission on first use.
- **Voice notes** (`speech_to_text`) and **offline outbox/sync** (drift/sqlite) are not
  wired yet (deferred in `app/pubspec.yaml` pending the AGP 7→8 bump); screens are
  online-first.
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
