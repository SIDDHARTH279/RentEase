# RentEase

Mobile-first rental property management for a single landlord. Django REST API + Flutter (Android/iOS).

## Stack

- **Backend:** Django, DRF, PostgreSQL, Redis, Celery, Channels (chat), Razorpay, FCM, SMTP
- **App:** Flutter, Riverpod, go_router, dio, firebase_messaging, Razorpay

## Monorepo

```
RentEase/
├── rentease-api/     # Django API
├── rentease_app/     # Flutter app
├── docker-compose.yml
├── PRODUCTION.md
└── RELEASE.md
```

## Local setup

### Infrastructure

```bash
docker compose up -d
```

Starts Postgres (`5432`) and Redis (`6379`).

### API

```bash
cd rentease-api
python -m venv venv
# Windows: .\venv\Scripts\activate
pip install -r requirements.txt
cp .env.example .env   # edit values
python manage.py migrate
python manage.py runserver 0.0.0.0:8000
```

Optional: Celery worker + beat for invoices/reminders.

### Flutter

```bash
cd rentease_app
flutter pub get
flutter run
```

Default API host is set in `lib/core/app_config.dart` (LAN IP for devices).
For production builds:

```bash
flutter build appbundle --dart-define=API_BASE_URL=https://YOUR_API_HOST
```

See `PRODUCTION.md` and `RELEASE.md` for deploy / store steps.

## Features

| Area | Status |
|---|---|
| Auth (JWT, Google, invites, strong passwords, rate limit) | Done |
| Profile (name, phone) + edit screen | Done |
| Portfolio → Building → Unit → Lease | Done |
| Billing + split shares + Razorpay + webhooks | Done |
| Issues | Done |
| Chat (Channels/WebSocket) | Done |
| Expenses + analytics charts | Done |
| Documents vault | Done |
| FCM + in-app notification center | Done |
| Email SMTP invites/reminders | Done |

## CI

GitHub Actions runs Django check/migrate and Flutter analyze on push/PR.
