#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEFAULT_CSV_FILE="$ROOT_DIR/supabase/seeds/external_source_game_mappings.csv"
DEFAULT_SQL_FILE="$ROOT_DIR/supabase/seeds/external_source_game_mappings.sql"

CSV_FILE="$DEFAULT_CSV_FILE"
SQL_FILE="$DEFAULT_SQL_FILE"

if [[ $# -gt 2 ]]; then
  echo "Usage: ./scripts/supabase-seed-external-source-mappings.sh [path/to/csv_file.csv|path/to/sql_file.sql] [path/to/output_seed.sql]" >&2
  exit 1
fi

if [[ $# -ge 1 ]]; then
  if [[ "$1" == *.sql ]]; then
    SQL_FILE="$1"
  else
    CSV_FILE="$1"
  fi
fi

if [[ $# -eq 2 ]]; then
  SQL_FILE="$2"
fi

if [[ ! -f "$CSV_FILE" ]]; then
  echo "Seed CSV file not found: $CSV_FILE" >&2
  echo "Usage: ./scripts/supabase-seed-external-source-mappings.sh [path/to/csv_file.csv|path/to/sql_file.sql] [path/to/output_seed.sql]" >&2
  exit 1
fi

echo "Generating external source game mappings seed SQL from CSV: $CSV_FILE"
"$ROOT_DIR/scripts/generate-external-source-mappings-seed.sh" "$CSV_FILE" "$SQL_FILE"

echo "Applying external source game mappings seed: $SQL_FILE"
"$ROOT_DIR/scripts/supabase-psql.sh" -v ON_ERROR_STOP=1 -f "$SQL_FILE"
