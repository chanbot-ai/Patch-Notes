#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "$ROOT_DIR/scripts/_supabase_env.sh"

if [[ -z "${PSQL_BIN:-}" ]]; then
  echo "psql not found. Expected /opt/homebrew/opt/libpq/bin/psql or a system 'psql' binary." >&2
  exit 1
fi

if [[ -n "${SUPABASE_PROJECT_REF:-}" && -n "${SUPABASE_DB_PASSWORD:-}" ]]; then
  export PGPASSWORD="$SUPABASE_DB_PASSWORD"
  exec "$PSQL_BIN" \
    "host=db.${SUPABASE_PROJECT_REF}.supabase.co port=5432 dbname=postgres user=postgres sslmode=require" \
    "$@"
fi

if [[ -z "${SUPABASE_DB_URL:-}" ]]; then
  echo "Missing DB connection settings. Set SUPABASE_PROJECT_REF + SUPABASE_DB_PASSWORD (preferred) or SUPABASE_DB_URL in .env.supabase.local." >&2
  exit 1
fi

exec "$PSQL_BIN" "$SUPABASE_DB_URL" "$@"
