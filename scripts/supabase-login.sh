#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "$ROOT_DIR/scripts/_supabase_env.sh"

if [[ -z "${SUPABASE_ACCESS_TOKEN:-}" ]]; then
  echo "SUPABASE_ACCESS_TOKEN is missing. Set it in .env.supabase.local (git-ignored)." >&2
  exit 1
fi

exec "$ROOT_DIR/scripts/supabase-cli.sh" login --token "$SUPABASE_ACCESS_TOKEN"
