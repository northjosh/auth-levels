# Auth Levels

Multi-factor authentication demo: a Spring Boot backend, a web frontend, and a Flutter companion app used to exercise the auth methods end to end.

## Auth Methods

- **Password** — account registration and login with JWT sessions.
- **TOTP** — time-based one-time passwords enrolled via an `otpauth://` QR code.
- **Recovery Code** — single-use codes issued at TOTP activation.
- **Passkey** — WebAuthn credentials bound to the user.
- **Magic Link** — emailed single-use login links.
- **Push Authentication** — a login on one device approved from a paired Trusted Device, using number matching.

Every login and account change is recorded as a Security Event (method, outcome, device, and network origin) and shown in the activity timeline.

## Components

| Component | What it is |
| --- | --- |
| `backend/` | Spring Boot (Java 21) REST API on port 8001. SQLite by default (`db.sqlite`); a Postgres service is available via `compose.yaml`. |
| `frontend/` | Vite + React 19 + TanStack Router/Query + Tailwind web app on port 3000. |
| `mobile/` | Flutter companion app: TOTP authenticator, Trusted Device pairing, push-login approval, and security activity. |

## Quick Start

### Backend

```bash
cd backend
./mvnw spring-boot:run
```

Backend starts on `http://localhost:8001`. SQLite needs no setup. For Postgres:

```bash
cd backend
docker-compose up -d
```

### Frontend

```bash
cd frontend
pnpm install
pnpm dev
```

Frontend starts on `http://localhost:3000`. Server state, routing, and component conventions follow the code in each package; see `DEVELOPMENT.md` for workflow details and `DEPLOYMENT.md` for production notes.

### Mobile

The Flutter app lives in `mobile/`. Push approval is delivered through Firebase Cloud Messaging using each install's Firebase Installation ID, so a Firebase project and generated.(Reverted back to FCM because FID's were hard to setup) `firebase_options.dart` (see `mobile/tool/gen_firebase_options.py`) are needed for push. Firebase is optional at runtime: without it the app pairs and works with push disabled.

```bash
cd mobile
flutter pub get
flutter run
```

App assets:

- `mobile/tool/gen_icon.py` renders the app icon (Pillow); `flutter_launcher_icons` stamps Android/iOS sizes.
- `mobile/tool/stub_server/` is the in-process contract stub used by API integration tests.

## Tests

```bash
cd backend && ./mvnw test
cd frontend && pnpm lint && pnpm build   # build runs tsc --noEmit
cd mobile && flutter test
```

## Repository Layout

```
backend/    Spring Boot API, DTOs, services, repositories
frontend/   Vite web app (src/routes, components, hooks)
mobile/     Flutter companion (lib/features, core/notifications)
```

This project is for educational and demonstration purposes.