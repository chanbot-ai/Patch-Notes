# Supabase Local Workflow (CLI + Direct SQL)

This repo is configured for both:

- Supabase CLI migrations (preferred for durable schema changes)
- Direct SQL via `psql` (useful for fast debugging/admin fixes)

## Security Guardrails

- Do **not** put any Supabase secrets in iOS app code.
- Do **not** commit local credentials to git.
- Keep secrets only in `.env.supabase.local` (git-ignored).
- Use the anon/publishable key only in the app.
- Service-role keys (if ever used for local admin/debugging) must stay in local env only.

## One-Time Local Setup

1. Copy the template:

   `cp .env.supabase.local.example .env.supabase.local`

2. Fill in:

- `SUPABASE_ACCESS_TOKEN` (Supabase personal access token)
- `SUPABASE_DB_PASSWORD` (project DB password)
- `SUPABASE_DB_URL` (optional direct `psql` URL; helper can build a connection from the project ref + DB password)

## Commands

- CLI version:
  `./scripts/supabase-cli.sh --version`

- Login CLI:
  `./scripts/supabase-login.sh`

- Link this repo to your Supabase project:
  `./scripts/supabase-link.sh`

- Create a migration:
  `./scripts/supabase-migration-new.sh add_users_rls_policies`

- Run direct SQL (interactive):
  `./scripts/supabase-psql.sh`

- Run direct SQL (one query):
  `./scripts/supabase-psql.sh -c "select now();"`

- Generate external source->game mappings seed SQL from CSV:
  `./scripts/generate-external-source-mappings-seed.sh`

- Apply external source->game mappings seed (X/Twitter handles -> `games`):
  `./scripts/supabase-seed-external-source-mappings.sh`
  (this regenerates SQL from CSV before apply)

## Recommended Usage Pattern

- Use migrations for schema, RLS, triggers, and repeatable changes.
- Use `psql` for fast inspection/debugging and one-off fixes during development.
- After one-off fixes, convert them into a migration so the repo remains authoritative.
- For repeatable admin mapping data (for example `external_source_game_mappings`), use CSV as source-of-truth at `supabase/seeds/external_source_game_mappings.csv`.
- Regenerate SQL with `./scripts/generate-external-source-mappings-seed.sh` and commit both CSV + SQL changes together.
- Apply with `./scripts/supabase-seed-external-source-mappings.sh` (auto-generates, then executes).
