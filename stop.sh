#!/bin/bash
# SupaStack — Stop all stacks gracefully.
# Does NOT remove volumes or data — safe to re-start with deploy.sh or setup.sh.
#
# Usage: bash stop.sh

set -e

ROOT="$(cd "$(dirname "$0")" && pwd)"
SUPABASE_DOCKER="$ROOT/supabase/docker"

echo ""
echo "======================================"
echo "  SupaStack — Stop"
echo "======================================"
echo ""

echo "[1/2] Stopping app stack..."
cd "$ROOT"
docker compose down
echo "      Done."

if [ -f "$SUPABASE_DOCKER/docker-compose.yml" ]; then
  echo "[2/2] Stopping Supabase stack..."
  cd "$SUPABASE_DOCKER"
  docker compose down
  echo "      Done."
else
  echo "[2/2] Supabase stack not found — skipping."
fi

echo ""
echo "======================================"
echo "  All stacks stopped."
echo "======================================"
echo ""
echo "  To start again:  bash deploy.sh"
echo ""
