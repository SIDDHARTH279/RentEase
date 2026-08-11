# RentEase — Deploy free on Oracle Cloud (Always Free)

This runs your full stack (API + Postgres + Redis + Celery) on a **permanent free** Oracle Cloud ARM VM using `docker-compose.prod.yml`.

## 0. What you need

- Oracle Cloud account: https://www.oracle.com/cloud/free/
- A domain is optional (you can use the VM public IP at first)
- Your laptop with this repo + Git (or GitHub)

Signup tip: choose a home region with free ARM capacity (often Mumbai `ap-mumbai-1`, Hyderabad, or nearby). If “Out of capacity”, try another AD/region or retry later.

## 1. Create Always Free VM

1. Oracle Console → **Compute → Instances → Create instance**
2. Image: **Canonical Ubuntu 22.04** (or 24.04)
3. Shape: **Ampere** / `VM.Standard.A1.Flex`
   - Prefer **2–4 OCPUs**, **12–24 GB RAM** (still Always Free within the 4 OCPU / 24 GB account limit)
4. Networking: create/use VCN, assign **public IP**
5. Add your SSH public key
6. Create instance → note **Public IP**

### Open ports (Critical)

**Networking → Virtual Cloud Networks → your VCN → Security Lists → Ingress rules**

Add:

| Source | Protocol | Port | Why |
|---|---|---|---|
| `0.0.0.0/0` | TCP | 22 | SSH |
| `0.0.0.0/0` | TCP | 80 | HTTP |
| `0.0.0.0/0` | TCP | 443 | HTTPS |
| `0.0.0.0/0` | TCP | 8000 | API (temporary; remove after HTTPS reverse proxy) |

Also allow the same in the instance firewall later (UFW).

## 2. SSH in and install Docker

```bash
ssh ubuntu@YOUR_PUBLIC_IP

sudo apt update && sudo apt upgrade -y
sudo apt install -y ca-certificates curl git ufw

# Docker
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker ubuntu
newgrp docker

docker --version
docker compose version
```

Firewall:

```bash
sudo ufw allow OpenSSH
sudo ufw allow 80
sudo ufw allow 443
sudo ufw allow 8000
sudo ufw --force enable
```

## 3. Put the project on the VM

**Option A — GitHub (recommended)**

```bash
git clone https://github.com/YOUR_USER/RentEase.git
cd RentEase
```

**Option B — copy from PC (PowerShell)**

```powershell
scp -r "C:\Users\st472\OneDrive\Desktop\Full Stack Projects\RentEase" ubuntu@YOUR_PUBLIC_IP:~/
```

Then on the VM: `cd ~/RentEase` (or `~/RentEase/RentEase` depending on copy path).

## 4. Create production `.env`

On the VM, in the repo root (same folder as `docker-compose.prod.yml`):

```bash
nano .env
```

Paste (edit values):

```env
SECRET_KEY=paste-a-long-random-string-here
DEBUG=False
ALLOWED_HOSTS=YOUR_PUBLIC_IP
CSRF_TRUSTED_ORIGINS=http://YOUR_PUBLIC_IP:8000
SECURE_SSL_REDIRECT=False

DB_NAME=rentease
DB_USER=rentease
DB_PASSWORD=pick-a-strong-db-password
DB_HOST=db
DB_PORT=5432

CELERY_BROKER_URL=redis://redis:6379/0
CELERY_RESULT_BACKEND=redis://redis:6379/0

EMAIL_HOST_USER=
EMAIL_HOST_PASSWORD=
GOOGLE_CLIENT_ID=your-google-web-client-id
PUBLIC_BASE_URL=http://YOUR_PUBLIC_IP:8000

RAZORPAY_KEY_ID=
RAZORPAY_KEY_SECRET=
RAZORPAY_WEBHOOK_SECRET=
```

Generate a secret:

```bash
python3 - <<'PY'
import secrets; print(secrets.token_urlsafe(50))
PY
```

> After you add HTTPS + domain later, set `ALLOWED_HOSTS`, `CSRF_TRUSTED_ORIGINS`, `PUBLIC_BASE_URL` to `https://api.yourdomain.com` and `SECURE_SSL_REDIRECT=True`.

## 5. Start the stack

```bash
docker compose -f docker-compose.prod.yml up -d --build
docker compose -f docker-compose.prod.yml ps
docker compose -f docker-compose.prod.yml logs -f api
```

Create admin:

```bash
docker compose -f docker-compose.prod.yml exec api python manage.py createsuperuser
```

Test in browser:

- `http://YOUR_PUBLIC_IP:8000/admin/`
- API should respond (login/register endpoints)

## 6. Point the Flutter app at the VM

On your PC:

```bash
cd rentease_app
flutter run --dart-define=API_BASE_URL=http://YOUR_PUBLIC_IP:8000
```

Release build later:

```bash
flutter build appbundle --dart-define=API_BASE_URL=http://YOUR_PUBLIC_IP:8000
```

When you have HTTPS domain, switch that URL to `https://...`.

## 7. Optional but recommended (still free)

### Free HTTPS with Cloudflare + Caddy/Nginx

1. Buy/use a free subdomain later, or Cloudflare on a domain you already have
2. Point DNS A record → VM IP
3. Put Caddy/Nginx in front of port 8000 for Let's Encrypt

Until then, HTTP on `:8000` is fine for your own testing.

### Keep the VM alive

- Oracle may reclaim idle Always Free resources rarely; keep the instance running
- Don’t store the only copy of data on the VM — occasionally dump DB:

```bash
docker compose -f docker-compose.prod.yml exec -T db \
  pg_dump -U rentease rentease > backup-$(date +%F).sql
```

## 8. Firebase / Google on free deploy

- Add the production API URL / package SHA to Firebase & Google Cloud OAuth
- `GOOGLE_CLIENT_ID` must be the **Web client ID** used to verify Google ID tokens
- For Android release, add release keystore SHA-1 to Firebase

## Troubleshooting

| Problem | Fix |
|---|---|
| Can’t create ARM instance | Retry, change availability domain/region |
| `Connection refused` on 8000 | Check Security List + UFW + `docker compose ps` |
| CSRF / admin issues | Set `CSRF_TRUSTED_ORIGINS` to exact URL you use |
| App can’t login | Flutter `API_BASE_URL` must match VM IP/URL; phone needs internet to that IP |
| Chat fails | Confirm Daphne is up (`api` service), not gunicorn/WSGI-only |
| Celery not sending invoices | Ensure `worker` + `beat` containers are running |

## Cost check

Always Free eligible shape + free Ubuntu image + no paid load balancer = **$0** if you stay within Always Free limits. Watch the Oracle billing page once after setup to confirm “$0 estimated”.
