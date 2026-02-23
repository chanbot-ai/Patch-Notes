#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "$ROOT_DIR/scripts/_supabase_env.sh"

if [[ -z "${SUPABASE_BIN:-}" ]]; then
  echo "Supabase CLI not found. Expected $ROOT_DIR/tools/bin/supabase or a system 'supabase' binary." >&2
  exit 1
fi

exec "$SUPABASE_BIN" "$@"
