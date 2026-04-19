# SupaStack — Boilerplate

A replicable full-stack template: React frontend, FastAPI backend, Supabase (self-hosted) for PostgreSQL + Auth + Storage. Clone, configure, start.

---

## Architecture

Two separate Docker Compose projects. Nginx is the single entry point — the browser never talks to the backend, Supabase, or Vite directly.

```
        Browser (any origin)
               │
               ▼
┌──────────────────────────────┐
│   Nginx  :2026               │
│                              │
│  /          → Vite :3000     │
│  /api/      → FastAPI :8080  │
│  /supabase/ → Kong :8000     │
└──────────────────────────────┘
        │            │
        ▼            ▼
  ┌──────────┐  ┌──────────────────┐
  │  FastAPI │  │ Supabase (Kong)  │
  └──────────┘  │  Auth · REST     │
        │       │  Studio · DB     │
        └───────┴──────────────────┘
                │  PostgreSQL
                ▼
         supabase-db:5432
```

Nginx connects to both `supastack_network` (frontend + backend) and `supabase_default` (Supabase stack), routing all browser traffic through a single port.

---

## Services & Ports

| Service             | URL                          | Description                     |
|---------------------|------------------------------|---------------------------------|
| **App (Nginx)**     | http://localhost:2026        | Single entry point for browser  |
| **Backend**         | http://localhost:8080        | FastAPI (also directly exposed) |
| **API Docs**        | http://localhost:2026/api/docs | Swagger UI                    |
| **Supabase Studio** | http://localhost:8000        | DB admin dashboard              |
| **Frontend (Vite)** | http://localhost:3000        | Dev server (direct)             |

Supabase Studio login credentials are in `supabase/docker/.env` (`DASHBOARD_USERNAME` / `DASHBOARD_PASSWORD`).

---

## Quick Start

### Automated setup (recommended)

```bash
bash setup.sh
```

Handles everything automatically: clones Supabase, generates secrets, starts and waits for all Supabase services (including analytics and Kong), configures `.env`, and runs migrations. Then jump straight to [Step 6](#step-6--start-the-app-stack).

> **Slow hardware (N100, Proxmox, VPS):** `setup.sh` waits up to 10 minutes per Supabase service — this is intentional.

---

### Manual setup

#### Step 1 — Clone the Supabase stack

Supabase is not included in this repo — clone it separately into the `supabase/` directory:

```bash
git clone --depth=1 https://github.com/supabase/supabase.git supabase
```

#### Step 2 — Generate Supabase secrets

```bash
cd supabase/docker
cp .env.example .env
sh ./utils/generate-keys.sh
```

This writes all generated values (`JWT_SECRET`, `ANON_KEY`, `SERVICE_ROLE_KEY`, etc.) directly into `supabase/docker/.env`.

#### Step 3 — Start Supabase

```bash
docker compose up -d

# Wait until analytics, db, and kong are all healthy (~2-5 min)
docker compose ps
```

If `kong` or `studio` remain in `Created` state, nudge them:
```bash
docker compose start kong studio
```

#### Step 4 — Configure app environment

```bash
# Go back to the supa-stack root
cd ../..
cp .env.example .env
```

Copy the relevant values from `supabase/docker/.env` into `.env`:

| `supabase/docker/.env`  | `.env`                              |
|-------------------------|-------------------------------------|
| `ANON_KEY`              | `ANON_KEY` + `VITE_SUPABASE_ANON_KEY` |
| `SERVICE_ROLE_KEY`      | `SERVICE_ROLE_KEY`                  |
| `JWT_SECRET`            | `JWT_SECRET`                        |
| `POSTGRES_PASSWORD`     | Replace in `DATABASE_URL`           |

```bash
# Quick way to display the values to copy
grep -E "^ANON_KEY|^SERVICE_ROLE_KEY|^JWT_SECRET|^POSTGRES_PASSWORD" supabase/docker/.env
```

#### Step 5 — Run database migrations

```bash
bash init-database.sh
```

Applies all SQL files from `db-migrations/` against the running `supabase-db` container in order.

#### Step 6 — Start the app stack

```bash
docker compose up -d
```

#### Step 7 — Done ✓

| What              | URL                            |
|-------------------|--------------------------------|
| App               | http://localhost:2026          |
| Backend + Swagger | http://localhost:2026/api/docs |
| Supabase Studio   | http://localhost:8000          |

---

## Deploying / Updating

```bash
bash deploy.sh
```

Pulls the latest code, applies any new migrations, and restarts the app stack. Safe to run on every update.

---

## Project Structure

```
supa-stack/
├── docker-compose.yaml         # App stack (Nginx + Backend + Frontend)
├── .env.example                # Environment template → copy to .env
├── .env                        # Your secrets (never commit!)
├── setup.sh                    # First-time setup
├── deploy.sh                   # Pull latest code + restart
├── init-database.sh            # Applies all DB migrations
│
├── nginx/
│   └── nginx.conf              # Reverse proxy config (single entry point)
│
├── db-migrations/              # SQL migrations (versioned, applied in order)
│   └── 001_create_key_value_items.sql
│
├── supabase/                   # Supabase self-hosted stack (git clone separately)
│   └── docker/
│       ├── docker-compose.yml
│       ├── .env                # Supabase secrets (never commit!)
│       └── utils/
│           └── generate-keys.sh
│
├── backend/                    # FastAPI (Python)
│   ├── Dockerfile
│   ├── requirements.txt
│   └── main.py
│
└── frontend/                   # React + TypeScript (Vite)
    ├── Dockerfile
    ├── package.json
    ├── vite.config.ts
    ├── tsconfig.json
    ├── index.html
    └── src/
        ├── main.tsx
        ├── App.tsx
        ├── index.css
        └── lib/
            └── supabase.ts     # Supabase client (URL auto-derived from origin)
```

---

## Nginx Routing

All browser traffic goes through Nginx on port 2026. No hardcoded URLs in the frontend.

| Path          | Proxies to          | Notes                              |
|---------------|---------------------|------------------------------------|
| `/`           | `frontend:3000`     | Vite dev server + HMR WebSocket    |
| `/api/`       | `backend:8080`      | FastAPI (prefix stripped)          |
| `/supabase/`  | `supabase-kong:8000`| Auth, REST, Realtime (prefix stripped) |

The Supabase JS client derives its URL from `window.location.origin`, so it automatically uses the correct origin whether the app is accessed from localhost, a local network IP, or a Cloudflare Tunnel — no environment variable needed.

---

## Database Migrations

SQL migrations live in `db-migrations/` and are applied in numeric order.

```bash
# Apply all migrations
bash init-database.sh

# Add a new migration
touch db-migrations/002_my_change.sql
# Write your SQL, then run:
bash init-database.sh
```

**Requirement:** Supabase stack must be running before applying migrations.

---

## Backend API

FastAPI running at `http://localhost:8080`. Interactive docs at `http://localhost:2026/api/docs`.

| Method   | Path            | Description                          |
|----------|-----------------|--------------------------------------|
| `GET`    | `/health`       | API + database connectivity check    |
| `GET`    | `/items`        | List all items                       |
| `GET`    | `/items/{id}`   | Get a single item by id              |
| `POST`   | `/items`        | Create a new item (`key`, `value`)   |
| `PATCH`  | `/items/{id}`   | Update an item (`key` and/or `value`)|
| `DELETE` | `/items/{id}`   | Delete an item by id                 |

```bash
curl http://localhost:2026/api/health

curl http://localhost:2026/api/items

curl -X POST http://localhost:2026/api/items \
  -H "Content-Type: application/json" \
  -d '{"key": "color", "value": "blue"}'

curl -X PATCH http://localhost:2026/api/items/1 \
  -H "Content-Type: application/json" \
  -d '{"value": "red"}'

curl -X DELETE http://localhost:2026/api/items/1
```

---

## Useful Commands

```bash
# --- App Stack ---
docker compose up -d                      # start all services
docker compose up -d --build backend      # rebuild and start backend
docker compose down                       # stop all services
docker compose logs -f backend            # tail backend logs
docker compose logs -f frontend           # tail frontend logs
docker compose restart nginx              # reload nginx config
docker compose up -d --no-build nginx     # recreate nginx (pick up network changes)

# --- Supabase Stack ---
cd supabase/docker
docker compose up -d                      # start Supabase
docker compose down                       # stop Supabase
docker compose ps                         # status of all services
docker compose exec db psql -U postgres   # direct DB shell

# --- Secrets rotation ---
cd supabase/docker
sh ./utils/generate-keys.sh               # regenerate all keys into .env
# Then update ANON_KEY + VITE_SUPABASE_ANON_KEY in supa-stack/.env
```

---

## Open Items / Next Steps

- [x] React + TypeScript frontend with key-value store demo
- [x] FastAPI backend with full CRUD API
- [x] Nginx single entry point (frontend + backend + Supabase)
- [x] Supabase Auth routed through Nginx (no hardcoded URLs)
- [x] Automated setup (`setup.sh`) and deploy (`deploy.sh`) scripts
- [x] Database migration pattern (`db-migrations/` + `init-database.sh`)
- [ ] CI/CD pipeline (GitHub Actions → auto deploy to VPS)
- [ ] PostgreSQL backup strategy
- [ ] Monitoring (e.g. Uptime Kuma)

---

## Architecture Decisions

See [architecture_template.md](./architecture_template.md)
