#!/bin/bash
# SupaStack — Development database reset
#
# Drops all application tables and reapplies all migrations from scratch.
# Safe to run repeatedly during development.
#
# Does NOT wipe Supabase volumes, auth config, or keys.
# Use this instead of nuking the entire Supabase stack.
#
# IMPORTANT: Edit the DROP TABLE statements below to match your project's tables.
#            List them in reverse dependency order (child tables first).
#
# Usage: bash reset-database.sh

set -e

ROOT="$(cd "$(dirname "$0")" && pwd)"

echo ""
echo "======================================"
echo "  SupaStack — Reset Database"
echo "======================================"
echo ""
echo "  Dropping application tables..."

# Drop all application tables in reverse dependency order.
# Supabase internal schemas (auth, storage, etc.) are not touched.
# ── Edit this block to match your project's tables ──────────────────────────
docker exec supabase-db psql -U postgres -d postgres <<'SQL'
-- Add your tables here, child tables first.
-- Example:
-- DROP TABLE IF EXISTS child_table  CASCADE;
-- DROP TABLE IF EXISTS parent_table CASCADE;
SQL

echo "  Done."
echo ""
echo "  Reapplying migrations..."
bash "$ROOT/init-database.sh"

echo ""
echo "======================================"
echo "  Database reset complete."
echo "======================================"
echo ""
