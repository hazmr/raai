# Raai (راعي) — Mobile App (Flutter)

The Android-first client for the Raai backend (`../server`). Two roles share one app:
**farmer** (owns the herd, pays) and **vet** (visitor who writes notes inside a visit).
Arabic-first (RTL), big touch targets, works offline. Full spec: `../FLUTTER_APP_DESIGN.md`.

## Status

Foundation + first vertical slice is built and **`flutter analyze` is clean**:

- ✅ Theme + design tokens (§1.1), Arabic/English l10n + RTL scaffold
- ✅ dio client (JWT attach, 401→refresh once, 402→paywall hook) + the single
  `ApiException` funnel + `errorText(code)` mapper (§6)
- ✅ Secure token store + Riverpod session/role state
- ✅ Login / Register (with farmer/vet toggle)
- ✅ go_router with the redirect guard (no token → login, logged in → role home, 402 → paywall)
- ✅ Bento home (farmer + vet variants)
- 🚧 Placeholders for: Herd list, Scan, Visits, Paywall (next build-order steps §5)
- ⬜ Not yet: animal detail + notes timeline, add-note sheet (templates/voice), the
  drift offline outbox + sync, full paywall flow

## Run it

```bash
flutter pub get
flutter gen-l10n          # generates lib/l10n/app_localizations*.dart
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080/api/v1
```

- `10.0.2.2` is the **Android emulator's** alias for your machine's `localhost`, where the
  backend runs on `:8080`. On a physical phone, use your computer's LAN IP, e.g.
  `--dart-define=API_BASE_URL=http://192.168.1.20:8080/api/v1`.
- The backend must be running (see `../server`). Register/login hit it directly.

Release build: `flutter build apk --release --dart-define=API_BASE_URL=https://your.api/api/v1`.

## Project layout

```
lib/
  main.dart                 # app, theme, localization, router
  core/
    theme.dart              # the §1.1 tokens, one ThemeData
    router.dart             # go_router + single redirect guard
    api/
      dio_client.dart       # base url, JWT interceptor, 401 refresh, 402 hook
      api.dart              # typed wrappers over /api/v1
      api_exception.dart    # the one error type every call funnels into
      error_text.dart       # code → friendly localized sentence (§6.2)
      models.dart           # DTOs mirroring the backend JSON
    auth/
      token_store.dart      # tokens in flutter_secure_storage
      session.dart          # Riverpod providers + session/role state
    widgets/coming_soon.dart
  features/
    auth/   home/   animals/   scan/   visits/   billing/
  l10n/                     # ar.arb (default), en.arb (+ generated *.dart)
```

## Conventions (keep these)

- **No hardcoded strings** — everything in `lib/l10n/*.arb`. Arabic is the default locale.
- **UI never reads dio** — call a method on `RaaiApi`, catch `ApiException`, show
  `errorText(t, e)`. The raw server message is for logs only, never displayed.
- **Design tokens only** — spacing `4/8/12/16/24`, radius `16/12`, min touch target 56 dp,
  one accent color. If a screen needs more, it's too complex.
- Add a dependency only if `FLUTTER_APP_DESIGN.md §2` lists it.

## Notes

- **Cairo font:** not bundled (no TTFs committed). The app falls back to the system font.
  To enable it, drop `Cairo-*.ttf` into `assets/fonts/` and uncomment the `fonts:` block in
  `pubspec.yaml`.
- Only the **Android** platform folder is generated. Add others later with
  `flutter create --platforms=ios,web .`.
