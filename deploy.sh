#!/bin/bash
# Deploy / refresh script for TradeTrust.
# Pulls the latest code from both repositories and restarts the app stack.
#
# Usage: bash deploy.sh

set -e

ROOT="$(cd "$(dirname "$0")" && pwd)"
SUPABASE_DIR="$ROOT/supabase"

echo ""
echo "======================================"
echo "  TradeTrust — Deploy"
echo "======================================"
echo ""

# -------------------------------------------------------
# Step 1: Pull latest app code
# -------------------------------------------------------
echo "[1/4] Pulling latest app code..."
git -C "$ROOT" pull
echo "      Done."

# -------------------------------------------------------
# Step 2: Pull latest Supabase repo
# -------------------------------------------------------
if [ -d "$SUPABASE_DIR/.git" ]; then
  echo "[2/4] Pulling latest Supabase repo..."
  git -C "$SUPABASE_DIR" pull
  echo "      Done."
else
  echo "[2/4] Supabase repo not found — skipping pull."
  echo "      Run setup.sh first if this is a fresh install."
fi

# -------------------------------------------------------
# Step 3: Run any new database migrations
# -------------------------------------------------------
echo "[3/4] Applying database migrations..."
if docker inspect --format='{{.State.Status}}' supabase-db 2>/dev/null | grep -q "running"; then
  bash "$ROOT/init-database.sh"
else
  echo ""
  echo "  WARNING: supabase-db is not running — skipping migrations."
  echo "  If this is a fresh install, run setup.sh first:"
  echo "    bash setup.sh"
  echo "  If Supabase is installed but stopped, start it:"
  echo "    cd supabase/docker && docker compose up -d"
  echo ""
fi

# -------------------------------------------------------
# Step 4: Rebuild and restart app containers
# -------------------------------------------------------
echo "[4/4] Rebuilding and restarting app containers..."
cd "$ROOT"
docker compose up -d --build
echo "      Done."

# -------------------------------------------------------
# Done
# -------------------------------------------------------
echo ""
echo "======================================"
echo "  Deploy complete!"
echo "======================================"
echo ""
echo "  App → http://localhost:2026"
echo ""
