# RentEase — Production guide

## 1. Harden / env

Set these on the host (never commit secrets):

| Variable | Purpose |
|---|---|
| `SECRET_KEY` | Long random Django secret |
| `DEBUG` | `False` |
| `ALLOWED_HOSTS` | API hostname (comma-separated) |
| `CSRF_TRUSTED_ORIGINS` | `https://your-api-host` |
| `DB_*` | Managed Postgres |
| `CELERY_BROKER_URL` / `CELERY_RESULT_BACKEND` | Redis URL |
| `EMAIL_HOST_USER` / `EMAIL_HOST_PASSWORD` | Gmail app password / SMTP |
| `GOOGLE_CLIENT_ID` | OAuth web client |
| `PUBLIC_BASE_URL` | Public `https://` API URL (invite links) |
| `RAZORPAY_*` | Optional platform defaults; owners can set keys in-app |

## 2. Deploy API (Docker)

From repo root, create a `.env` with production values, then:

```bash
docker compose -f docker-compose.prod.yml up -d --build
```

Services: `api` (Daphne/ASGI), `worker`, `beat`, `db`, `redis`.

Or deploy `rentease-api/Dockerfile` on Railway / Render / Fly:

1. Attach Postgres + Redis
2. Set env vars above (`DEBUG=False`)
3. Run migrate on start (compose already does)
4. Start Celery worker + beat as separate processes

Create a superuser once:

```bash
docker compose -f docker-compose.prod.yml exec api python manage.py createsuperuser
```

## 3. Point the Flutter app at production

Local default stays your LAN IP. For release / TestFlight / Play:

```bash
flutter build appbundle --dart-define=API_BASE_URL=https://YOUR_API_HOST
flutter build ipa --dart-define=API_BASE_URL=https://YOUR_API_HOST
```

Debug against prod:

```bash
flutter run --dart-define=API_BASE_URL=https://YOUR_API_HOST
```

WebSockets use `wss://` automatically when the API URL is `https://`.

## 4. Google / Firebase / Razorpay

- Add production Android SHA-1/256 to Firebase + Google OAuth
- Set `GOOGLE_CLIENT_ID` to the Web client ID used to verify ID tokens
- Razorpay webhook: `https://YOUR_API/api/v1/billing/webhooks/razorpay/`
- Owners can paste live keys in **Payment settings** (encrypted at rest)

## 5. Media / backups / monitoring

- Local `MEDIA_ROOT` is fine for early beta; move to S3/R2 before scale
- Enable Postgres automated backups
- Keep `firebase-service-account.json` only on the server
- Optional: Sentry for Django + Flutter

## 6. Store release

See [RELEASE.md](RELEASE.md) for Play Store / App Store steps.
