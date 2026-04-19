#!/bin/bash
# First-time setup script for SupaStack.
# Run this once after cloning the repo.
#
# Usage: bash setup.sh
#
# Tested on: macOS, Debian/Ubuntu

set -e

ROOT="$(cd "$(dirname "$0")" && pwd)"
SUPABASE_DIR="$ROOT/supabase"
SUPABASE_DOCKER="$SUPABASE_DIR/docker"
SUPABASE_ENV="$SUPABASE_DOCKER/.env"
APP_ENV="$ROOT/.env"

# Portable in-place sed: macOS needs an empty string argument, Linux does not
portable_sed() {
  if [[ "$OSTYPE" == "darwin"* ]]; then
    sed -i '' "$@"
  else
    sed -i "$@"
  fi
}

echo ""
echo "======================================"
echo "  TradeTrust — First-time Setup"
echo "======================================"
echo ""

# -------------------------------------------------------
# Step 1: Clone Supabase
# -------------------------------------------------------
if [ -d "$SUPABASE_DIR/.git" ]; then
  echo "[1/6] Supabase repo already cloned — skipping."
else
  echo "[1/6] Cloning Supabase repository (this may take a minute)..."
  git clone --depth=1 https://github.com/supabase/supabase.git "$SUPABASE_DIR"
  echo "      Done."
fi

# -------------------------------------------------------
# Step 2: Create Supabase .env and configure it
# -------------------------------------------------------
if [ -f "$SUPABASE_ENV" ]; then
  echo "[2/6] supabase/docker/.env already exists — skipping."
else
  echo "[2/6] Creating supabase/docker/.env from example..."
  cp "$SUPABASE_DOCKER/.env.example" "$SUPABASE_ENV"
fi

# -------------------------------------------------------
# Step 3: Generate Supabase secrets
# -------------------------------------------------------
echo "[3/6] Generating Supabase secrets..."
if [ -f "$SUPABASE_DOCKER/utils/generate-keys.sh" ]; then
  cd "$SUPABASE_DOCKER"
  sh ./utils/generate-keys.sh
  cd "$ROOT"
  echo "      Secrets generated."
else
  echo "      generate-keys.sh not found — skipping (keys from .env.example will be used)."
  echo "      WARNING: Change these before going to production!"
fi

# -------------------------------------------------------
# Step 4: Start Supabase
# -------------------------------------------------------
echo "[4/6] Starting Supabase stack..."
cd "$SUPABASE_DOCKER"
docker compose up -d
echo ""
echo "      Supabase is starting — on slower hardware this can take 5+ minutes."
echo "      Waiting for supabase-db to become healthy..."

# Wait for supabase-db (max 10 min, 10 s intervals)
wait_healthy() {
  local CONTAINER=$1
  local LABEL=$2
  local RETRIES=60
  echo "      Waiting for $LABEL..."
  until docker inspect --format='{{.State.Health.Status}}' "$CONTAINER" 2>/dev/null | grep -q "healthy"; do
    RETRIES=$((RETRIES - 1))
    if [ $RETRIES -eq 0 ]; then
      echo ""
      echo "ERROR: $CONTAINER did not become healthy in time."
      echo "Check logs: cd supabase/docker && docker compose logs"
      exit 1
    fi
    printf "."
    sleep 10
  done
  echo " healthy."
}

wait_healthy supabase-db       "database"
wait_healthy supabase-analytics "analytics (required by kong)"

# analytics can be slow — kong and studio depend on it and may need a nudge
echo "      Starting kong and studio..."
docker compose start kong studio 2>/dev/null || true

wait_healthy supabase-kong "kong (API gateway)"

cd "$ROOT"

# -------------------------------------------------------
# Step 5: Create and populate app .env
# -------------------------------------------------------
echo "[5/6] Configuring app .env..."

if [ ! -f "$APP_ENV" ]; then
  cp "$ROOT/.env.example" "$APP_ENV"
fi

# Ensure current user can write the file (may be owned by root from a prior run)
chmod u+w "$APP_ENV"

ANON_KEY=$(grep "^ANON_KEY=" "$SUPABASE_ENV" | cut -d= -f2-)
SERVICE_ROLE_KEY=$(grep "^SERVICE_ROLE_KEY=" "$SUPABASE_ENV" | cut -d= -f2-)
JWT_SECRET=$(grep "^JWT_SECRET=" "$SUPABASE_ENV" | cut -d= -f2-)
POSTGRES_PASSWORD=$(grep "^POSTGRES_PASSWORD=" "$SUPABASE_ENV" | cut -d= -f2-)

portable_sed -e "s|ANON_KEY=.*|ANON_KEY=$ANON_KEY|" "$APP_ENV"
portable_sed -e "s|VITE_SUPABASE_ANON_KEY=.*|VITE_SUPABASE_ANON_KEY=$ANON_KEY|" "$APP_ENV"
portable_sed -e "s|SERVICE_ROLE_KEY=.*|SERVICE_ROLE_KEY=$SERVICE_ROLE_KEY|" "$APP_ENV"
portable_sed -e "s|JWT_SECRET=.*|JWT_SECRET=$JWT_SECRET|" "$APP_ENV"
portable_sed -e "s|DATABASE_URL=.*|DATABASE_URL=postgresql://postgres:$POSTGRES_PASSWORD@supabase-db:5432/postgres|" "$APP_ENV"

echo "      .env configured."

# -------------------------------------------------------
# Step 6: Run database migrations
# -------------------------------------------------------
echo "[6/6] Running database migrations..."
bash "$ROOT/init-database.sh"

# -------------------------------------------------------
# Done
# -------------------------------------------------------
echo ""
echo "======================================"
echo "  Setup complete!"
echo "======================================"
echo ""
echo "  Start the app stack:"
echo "    docker compose up -d"
echo ""
echo "  Services:"
echo "    App (via Nginx)     → http://localhost:2026"
echo "    Backend API + Docs  → http://localhost:8080/docs"
echo "    Supabase Studio     → http://localhost:8000"
echo ""
echo "  Supabase Studio login:"
DASH_USER=$(grep "^DASHBOARD_USERNAME=" "$SUPABASE_ENV" | cut -d= -f2-)
DASH_PASS=$(grep "^DASHBOARD_PASSWORD=" "$SUPABASE_ENV" | cut -d= -f2-)
echo "    Username: ${DASH_USER:-supabase}"
echo "    Password: ${DASH_PASS:-see supabase/docker/.env}"
echo ""
