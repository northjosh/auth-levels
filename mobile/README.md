# auth-levels mobile companion

Flutter app that acts as a TOTP authenticator, a Trusted Device for push-login approval, and a viewer of the account's security activity. Spec: `../.scratch/mobile-companion-app/spec.md`; API: `../.scratch/mobile-companion-app/api-contract.md`.

## Run

```sh
flutter emulators --launch pixel_api35_gapis   # Android (push works here)
flutter run -d emulator-5554

open -a Simulator                              # iOS simulator (everything but push)
flutter run -d "iPhone 16e"                    # needs the iOS platform for your Xcode: xcodebuild -downloadPlatform iOS
```

Backend base URL comes from the pairing link: `http://10.0.2.2:8001` on the Android emulator, `http://localhost:8001` on the iOS simulator.

To scan a QR on the Android emulator, feed it a picture as the back camera: render the code onto a 4:3 white canvas with the code in the left third (the emulator right-aligns the image in its frame), then launch with `emulator @pixel_api35_gapis -camera-back imagefile:/path/to/qr.png`.

Firebase config files (`android/app/google-services.json`, `ios/Runner/GoogleService-Info.plist`) are gitignored; copies live in `../.scratch/mobile-companion-app/firebase/`. The app initialises Firebase from `lib/firebase_options.dart`, generated (and gitignored) by:

```sh
python3 tool/gen_firebase_options.py
```

Run it once before the first build. Without the config files it writes a placeholder instead, and the app still builds and runs; it just pairs with `fcmToken: null` ("Push off").

## Push notifications

A Push Request arrives as a real FCM notification on the Android emulator (Google APIs image). To send one without the real backend, copy the FCM token from Settings → Push token and run:

```sh
cd tool/send_push && dart pub get
dart run bin/send_push.dart --token <fcm token> --stub http://localhost:8002
```

It uses `~/.config/auth-levels/firebase-adminsdk.json` (or `GOOGLE_APPLICATION_CREDENTIALS`), creates a request on the stub so the tap lands on a live one, and prints the code to approve with. Drop `--stub` to send a message for a random request id (lands on the "Request gone" state).

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
  core/        api client, secure storage, QR scanner, notifications
  features/    authenticator, account, pairing, requests, activity, settings
```
