#!/bin/bash
# Run all migrations in db-migrations/ in order against the Supabase PostgreSQL container.

set -e

MIGRATIONS_DIR="$(dirname "$0")/db-migrations"
DB_CONTAINER="supabase-db"
DB_USER="postgres"
DB_NAME="postgres"

echo "Running migrations from: $MIGRATIONS_DIR"
echo ""

for file in "$MIGRATIONS_DIR"/*.sql; do
    echo "Applying: $(basename "$file") ..."
    docker exec -i "$DB_CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" < "$file"
    echo "Done: $(basename "$file")"
    echo ""
done

echo "All migrations applied."
