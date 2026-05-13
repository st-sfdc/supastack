#!/bin/bash
# SupaStack — Deploy script
#
# Usage:
#   bash deploy.sh             Fast deploy    — git pull + migrations + restart app containers
#   bash deploy.sh --rebuild   Rebuild deploy — git pull + migrations + rebuild app images (no Supabase restart)
#   bash deploy.sh --full      Full deploy    — rebuild everything including Supabase restart
#
# Fast deploy    → routine code pushes (no Dockerfile / config changes)
# Rebuild deploy → nginx.conf, Dockerfile, requirements.txt, or package.json changed
# Full deploy    → Supabase config or env changed; first deploy on a new server

set -e

ROOT="$(cd "$(dirname "$0")" && pwd)"
SUPABASE_DOCKER="$ROOT/supabase/docker"
SUPABASE_ENV="$SUPABASE_DOCKER/.env"

FULL=false
REBUILD=false
if [[ "$1" == "--full" ]]; then
  FULL=true
elif [[ "$1" == "--rebuild" ]]; then
  REBUILD=true
fi

portable_sed() {
  if [[ "$OSTYPE" == "darwin"* ]]; then
    sed -i '' "$@"
  else
    sed -i "$@"
  fi
}

wait_healthy() {
  local CONTAINER=$1
  local LABEL=$2
  local RETRIES=60
  echo "      Waiting for $LABEL..."
  until docker inspect --format='{{.State.Health.Status}}' "$CONTAINER" 2>/dev/null | grep -q "healthy"; do
    RETRIES=$((RETRIES - 1))
    if [ "$RETRIES" -eq 0 ]; then
      echo ""
      echo "ERROR: $CONTAINER did not become healthy in time."
      echo "Check logs: cd supabase/docker && docker compose logs $CONTAINER"
      exit 1
    fi
    printf "."
    sleep 10
  done
  echo " healthy."
}

echo ""
echo "======================================"
if [ "$FULL" = true ]; then
  echo "  SupaStack — Full Deploy"
elif [ "$REBUILD" = true ]; then
  echo "  SupaStack — Rebuild Deploy"
else
  echo "  SupaStack — Fast Deploy"
fi
echo "======================================"
echo ""

# ── Step 1: Pull latest app code ────────────────────────────────────────────
echo "[1] Pulling latest app code..."
git -C "$ROOT" pull
echo "    Done."

if [ "$FULL" = true ]; then

  # ── Full: stop app stack ─────────────────────────────────────────────────
  echo "[2] Stopping app stack..."
  cd "$ROOT" && docker compose down
  echo "    Done."

  # ── Full: stop Supabase ──────────────────────────────────────────────────
  if [ -f "$SUPABASE_DOCKER/docker-compose.yml" ]; then
    echo "[3] Stopping Supabase stack..."
    cd "$SUPABASE_DOCKER" && docker compose down
    echo "    Done."
  else
    echo "[3] Supabase stack not found — skipping."
  fi

  # ── Full: pull latest Supabase repo ─────────────────────────────────────
  if [ -d "$ROOT/supabase/.git" ]; then
    echo "[4] Pulling latest Supabase repo..."
    git -C "$ROOT/supabase" pull
    echo "    Done."
  else
    echo "[4] Supabase repo not found — skipping."
  fi

  # ── Full: start Supabase and wait for health ─────────────────────────────
  echo "[5] Starting Supabase stack..."
  cd "$SUPABASE_DOCKER" && docker compose up -d
  echo ""
  wait_healthy supabase-db        "database"
  wait_healthy supabase-analytics "analytics"
  echo "    Starting kong and studio..."
  docker compose start kong studio 2>/dev/null || true
  wait_healthy supabase-kong "kong (API gateway)"
  cd "$ROOT"

fi

# ── Migrations (always) ───────────────────────────────────────────────────────
if [ "$FULL" = true ]; then
  STEP_MIGRATE=6
else
  STEP_MIGRATE=2
fi
echo "[$STEP_MIGRATE] Applying database migrations..."
if docker inspect --format='{{.State.Status}}' supabase-db 2>/dev/null | grep -q "running"; then
  bash "$ROOT/init-database.sh"
else
  echo ""
  echo "  WARNING: supabase-db is not running — skipping migrations."
  echo "  Run setup.sh first if this is a fresh install."
  echo ""
fi
echo "    Done."

# ── Start / restart app stack ─────────────────────────────────────────────────
if [ "$FULL" = true ]; then
  STEP_APP=7
else
  STEP_APP=3
fi
if [ "$FULL" = true ]; then
  echo "[$STEP_APP] Rebuilding and starting app stack..."
  cd "$ROOT" && docker compose up -d --build
elif [ "$REBUILD" = true ]; then
  echo "[$STEP_APP] Rebuilding app stack (Supabase untouched)..."
  cd "$ROOT" && docker compose up -d --build --no-deps nginx frontend backend
else
  echo "[$STEP_APP] Restarting app stack..."
  cd "$ROOT" && docker compose restart
fi
echo "    Done."

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "======================================"
echo "  Deploy complete!"
echo "======================================"
echo ""
echo "  App       → http://localhost:2026"
echo "  API Docs  → http://localhost:8080/docs"
echo "  Studio    → http://localhost:8000"
echo ""
