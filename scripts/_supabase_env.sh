#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$ROOT_DIR/.env.supabase.local"

if [[ -f "$ENV_FILE" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  set +a
fi

SUPABASE_BIN_DEFAULT="$ROOT_DIR/tools/bin/supabase"
if [[ -x "$SUPABASE_BIN_DEFAULT" ]]; then
  export SUPABASE_BIN="$SUPABASE_BIN_DEFAULT"
elif command -v supabase >/dev/null 2>&1; then
  export SUPABASE_BIN="$(command -v supabase)"
else
  export SUPABASE_BIN=""
fi

PSQL_BIN_DEFAULT="/opt/homebrew/opt/libpq/bin/psql"
if [[ -x "$PSQL_BIN_DEFAULT" ]]; then
  export PSQL_BIN="$PSQL_BIN_DEFAULT"
elif command -v psql >/dev/null 2>&1; then
  export PSQL_BIN="$(command -v psql)"
else
  export PSQL_BIN=""
fi
