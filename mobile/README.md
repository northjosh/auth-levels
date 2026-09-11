# auth-levels mobile companion

Flutter app that acts as a TOTP authenticator, a Trusted Device for push-login approval, and a viewer of the account's security activity. Spec: `../.scratch/mobile-companion-app/spec.md`; API: `../.scratch/mobile-companion-app/api-contract.md`.

## Run

```sh
flutter emulators --launch pixel_api35_gapis   # Android (push works here)
flutter run -d emulator-5554

open -a Simulator                              # iOS simulator (everything but push)
flutter run -d "iPhone 16"
```

Backend base URL comes from the pairing link: `http://10.0.2.2:8001` on the Android emulator, `http://localhost:8001` on the iOS simulator.

Firebase config files (`android/app/google-services.json`, `ios/Runner/GoogleService-Info.plist`) are gitignored; copies live in `../.scratch/mobile-companion-app/firebase/`.

## Stub backend

`tool/stub_server/` is an in-memory stand-in for the real backend, following the API contract. Use it until the Spring backend has the device, push and security-event routes.

```sh
cd tool/stub_server && dart pub get
dart run bin/server.dart --port 8002          # add --skew 90 to test the clock-skew banner
```

It prints a pairing link per target — `http://10.0.2.2:8002` for the Android emulator, `http://localhost:8002` for the iOS simulator — plus the code of one seeded Push Request (expires two minutes after boot — use `/__push` for a fresh one). Any enrollment token starting with `ok-` pairs; `expired-` returns `410`. Admin routes: `POST /__push` creates a new pending request (returns its code), `POST /__revoke` revokes every paired device. Tests: `dart test`.

## Layout

```
lib/
  app/         router, theme, two-tab shell
  core/        api client, secure storage, notifications
  features/    authenticator, account, pairing, requests, activity, settings
```
