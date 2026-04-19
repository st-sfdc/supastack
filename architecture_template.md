# SupaStack — Architecture Decisions

> This document captures the foundational architecture decisions for a replicable application template. It serves as a reference and starting point for new projects.

---

## Overview

The goal is a **replicable full-stack template** ("SupaStack") that serves as a starting point for different projects. The architecture follows a classic **SPA + REST API + Database** pattern, fully containerised and self-hosted.

```
        Browser / Mobile / iOS
               │  single origin (any URL)
               ▼
┌──────────────────────────────┐
│   Nginx  :2026               │  single entry point
│                              │
│  /          → Vite :3000     │
│  /api/      → FastAPI :8080  │
│  /supabase/ → Kong :8000     │
└──────────────────────────────┘
        │                │
        ▼                ▼
  ┌──────────┐    ┌──────────────────────────┐
  │  FastAPI │    │  Supabase (self-hosted)   │
  │  :8080   │    │  Auth · REST · Studio     │
  └──────────┘    │  Kong :8000               │
        │         └──────────────────────────┘
        └─────────────────┐
                          ▼
                   supabase-db:5432
                      PostgreSQL
```

Nginx is the single entry point for all browser traffic. The frontend never contains hardcoded backend, API, or Supabase URLs — it derives everything from `window.location.origin`, making the app portable across localhost, local network, and public domains without configuration changes.

---

## Decisions in Detail

### 1. Architecture Pattern

| Decision | Chosen | Rationale |
|---|---|---|
| Pattern | SPA + REST Backend | Clear separation of concerns, easy to replicate |
| API style | REST | Battle-tested, easy to debug, good AI/Cursor support |
| Microservices? | No | Monolithic backend — easier to start, splittable later |

The backend is structured in three internal layers:
- **Routes / Controller** — HTTP handling, validation
- **Business Logic** — domain rules, workflows
- **Data Access Layer** — database queries

### 2. Authentication & Identity

| Decision | Chosen |
|---|---|
| Identity Provider | Supabase Auth (self-hosted) |
| Login methods | Email + password, Social (Google, Apple), Magic Link |
| MFA | Supported, enable when needed |
| Token format | JWT (OAuth2-compatible) |
| Tenant model | Single-tenant — all users are customers of the same system |

**Rationale:** Supabase Auth supports all required login methods natively, is based on open standards (PostgreSQL, JWT), and is self-hostable — no proprietary lock-in.

### 3. Database

| Decision | Chosen |
|---|---|
| Primary DB | PostgreSQL (via Supabase) |
| Hosting | Self-hosted (Docker) |
| Schema management | Numbered SQL migration files in `db-migrations/` |
| Applying migrations | `init-database.sh` (via `docker exec` into `supabase-db`) |

**Rationale:** PostgreSQL is the most reliable, feature-rich open source database. Self-hosted via Supabase means full control and portability — it is plain PostgreSQL, migratable at any time.

**Migration pattern:** Each schema change is a numbered SQL file (`001_create_x.sql`, `002_add_y.sql`). Files are committed to git alongside application code, giving a versioned, reproducible schema history. `init-database.sh` applies all files in order on every run (idempotent via `IF NOT EXISTS`).

### 4. Backend

| Decision | Chosen |
|---|---|
| Language | Python |
| Framework | FastAPI |
| API style | REST |

**Rationale:**
- Python has the best AI-tool (Cursor) support
- FastAPI is modern, typed (via Pydantic), auto-generates API docs (Swagger/OpenAPI)
- Highly readable — easy to debug without deep Python expertise
- No callback hell, synchronous thinking possible

### 5. Frontend (Web)

| Decision | Chosen |
|---|---|
| Framework | React |
| Language | TypeScript |
| App type | Single Page Application (SPA) |
| Build tool | Vite |
| UI library | shadcn/ui or Ant Design (recommended) |

**Rationale:** React + TypeScript has the best AI/Cursor support and largest ecosystem. TypeScript eliminates the typing problems of JavaScript. shadcn/ui enables professional UIs without deep CSS effort.

### 6. Mobile & iOS (future)

| Decision | Status |
|---|---|
| Strategy | Option kept open |
| Recommendation when relevant | Flutter (cross-platform) or Swift/SwiftUI (iOS-only) |

The REST API backend is client-agnostic by design — any app that speaks HTTP can use it. Mobile and iOS are therefore retrofittable without architecture changes.

**Template ecosystem vision:** The long-term goal is a set of client templates (web, mobile, iOS) that all share this same backend/Supabase core. Each client template is a separate repo, consuming the same REST API. This creates a personal app factory — clone the relevant client template, point it at a fresh Supabase instance, and start building.

### 7. Hosting & Deployment

| Layer | Technology |
|---|---|
| Containerisation | Docker + Docker Compose |
| Local development | Docker Desktop / Proxmox |
| Production | VPS (e.g. Hetzner, home server) |
| Reverse proxy | Nginx (plain `nginx:alpine`, config in `nginx/nginx.conf`) |
| Public access | Cloudflare Tunnel (no open firewall ports required) |
| Supabase | Self-hosted in separate Docker Compose stack |

**Deployment principle:** Everything runs in Docker Compose. The step from local to production is: install Docker on VPS, `git clone`, `bash setup.sh`, done. No differences between development and production environments.

**Single entry point:** Nginx runs on one port (2026) and proxies all traffic internally — frontend (Vite), backend API (`/api/`), and Supabase (`/supabase/`). The Cloudflare Tunnel points at this single port. No other ports need to be exposed publicly.

**`setup.sh` / `deploy.sh`:** First-time setup is fully automated via `setup.sh` (clones Supabase, generates secrets, waits for all services, runs migrations). Subsequent deploys use `deploy.sh` (git pull, migrations, restart).

**Migration path:**
```
Local (Docker) → VPS (Hetzner/DigitalOcean) → optional Cloud (AWS/GCP)
```

### 8. Template Replication Pattern

A new project is started by cloning this template into a new product repo:

```bash
git clone <supastack-repo> my-new-app
cd my-new-app
rm -rf .git && git init
git add . && git commit -m "Initial commit (from supastack template)"
git remote add origin <new-repo-url>
git push -u origin main
```

To pull future template improvements into an existing product repo:

```bash
git remote add template <supastack-repo-url>
git fetch template
git merge template/main --allow-unrelated-histories
```

For minor changes (e.g. a script fix), manual copy is often simpler than the merge approach.

---

## Full Stack Overview

```
Auth:       Supabase Auth      (self-hosted, JWT/OAuth2)
DB:         PostgreSQL         (self-hosted via Supabase)
Migrations: SQL files          (db-migrations/ + init-database.sh)
Backend:    Python + FastAPI   (Docker container)
API:        REST
Frontend:   React + TypeScript (Docker container, Vite dev server)
Mobile:     Flutter            (future option)
iOS:        Swift/SwiftUI      (future option)
Proxy:      Nginx              (nginx:alpine, single entry point on :2026)
Public:     Cloudflare Tunnel  (no open ports required)
Hosting:    Docker Compose on Proxmox / VPS
Setup:      setup.sh + deploy.sh (fully automated)
```

---

## Open Decisions

- [x] **Infrastructure as code** — `setup.sh` (first-time) and `deploy.sh` (updates) fully automate the lifecycle
- [x] **Template replication** — git subtree push to publish; git remote to pull updates into product repos
- [x] **Database migration pattern** — numbered SQL files in `db-migrations/`, applied via `init-database.sh`
- [x] **Mobile strategy** — Flutter for cross-platform, Swift/SwiftUI for iOS-only; deferred to when relevant
- [x] **Reverse proxy** — plain Nginx as single entry point; all traffic (frontend, API, Supabase) through one port
- [x] **Public access** — Cloudflare Tunnel; no firewall ports need to be opened
- [x] **URL portability** — frontend derives all URLs from `window.location.origin`; works on any domain
- [ ] **CI/CD Pipeline** — GitHub Actions for automatic deployment
- [ ] **Monitoring & Logging** — how are errors and performance tracked?
- [ ] **Backup strategy** — automated PostgreSQL backups
- [ ] **SSL/TLS** — handled by Cloudflare Tunnel (automatic)

---

## Architecture Principles

1. **Replicability over perfection** — the template must be quickly applicable to new projects
2. **No proprietary lock-in** — all components are based on open standards
3. **Docker-first** — local development = production, no surprises
4. **AI-friendly** — technology choices optimised for Cursor/vibe coding with human control
5. **Evolutionary** — architecture can grow (microservices, cloud migration) without a rebuild
6. **Client-agnostic backend** — the REST API serves any client (web, mobile, iOS) without modification

---

*Last updated: April 2026*
