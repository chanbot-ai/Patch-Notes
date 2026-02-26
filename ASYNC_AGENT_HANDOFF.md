# Async Agent Handoff (`codex/async-dev`)

This file is updated by Codex during asynchronous work sessions so changes are easy to review later.

## Current Status

- Branch: `codex/async-dev`
- Mode: Async development active
- Last milestone: Remote secrets audit confirmed syncTweets provider key is still missing

## Latest Milestone

### Summary

- Executed the recommended Supabase infra follow-up and enabled `pg_cron` + `pg_net` on the remote database (they were available but not installed).
- Verified `app.settings.supabase_url` / `app.settings.supabase_anon_key` still cannot be set from this DB connection (`permission denied to set parameter`) via both `ALTER DATABASE` and `ALTER ROLE`, so the migration-based scheduler path remains blocked on admin/dashboard-level config.
- Used a safe operational fallback to manually register `tweets_cache_retention_daily` and `sync_tweets_cache_30m` cron jobs directly in `cron.job` (including `Authorization` + `apikey` headers for the `syncTweets` Edge Function call).
- Verified authenticated `syncTweets` requests now reach function logic and fail on the next blocker: missing Edge Function env `TWITTERAPI_IO_API_KEY`.
- Queried remote Supabase secrets via CLI and confirmed `TWITTERAPI_IO_API_KEY` is not present (only Supabase URL/DB/auth keys are configured), so this run is blocked on missing provider credentials rather than cron wiring.

### Files Touched

- `ASYNC_AGENT_HANDOFF.md`

### Migrations Applied

- No new repo migration this run.
- Remote status: `20260226163000_fix_sync_tweets_cron_auth_headers.sql` remains applied, but its scheduling logic no-op'd earlier due missing `cron` at the time. Cron jobs were registered manually this run after enabling extensions.

### Verification

- Remote DB extension checks (`scripts/supabase-psql.sh`):
  - `pg_available_extensions` includes `pg_cron` and `pg_net`
  - `create extension if not exists pg_net;` succeeded
  - `create extension if not exists pg_cron;` succeeded
- `app.settings.*` write attempts:
  - `ALTER DATABASE postgres SET "app.settings.supabase_url" ...` -> `permission denied to set parameter "app.settings.supabase_url"`
  - `ALTER ROLE postgres SET "app.settings.supabase_url" ...` -> same permission error
- Cron scheduling fallback (`scripts/supabase-psql.sh` manual SQL):
  - registered active jobs in `cron.job`:
    - `sync_tweets_cache_30m` (`*/30 * * * *`)
    - `tweets_cache_retention_daily` (`15 4 * * *`)
- Edge Function probe (network-enabled `curl` with valid anon auth headers):
  - reached function runtime and returned `500` with `Missing required env: TWITTERAPI_IO_API_KEY`
- Remote secrets audit (`scripts/supabase-cli.sh secrets list --project-ref <ref>`):
  - confirmed `TWITTERAPI_IO_API_KEY` is absent on the project
  - present secrets are limited to Supabase connection/auth values (`SUPABASE_URL`, `SUPABASE_DB_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY`)

### Open Risks / Notes

- `sync_tweets_cache_30m` is now scheduled, but it will fail until Supabase Edge Function `syncTweets` has `TWITTERAPI_IO_API_KEY` configured (and likely handle allowlist env vars if not already set).
- This workspace/local env does not currently contain the twitterapi.io key, so the credential must be supplied out-of-band (Supabase dashboard/CLI secret set) before the next automation run can complete a write verification.
- Manual cron scheduling embeds the anon key in the cron job command text as a stopgap because `app.settings.*` writes are blocked from this connection. Prefer replacing with the migration-driven `app.settings` path once admin-level config is available.
- `public.tweets_cache` remains empty until the function env is completed and a sync run succeeds.

## Next Recommended Action

- Set Supabase Edge Function secret `TWITTERAPI_IO_API_KEY` (and confirm `TWITTER_SYNC_ALLOWED_HANDLES` / related sync envs) via Supabase dashboard/CLI, then trigger a small authenticated `syncTweets` run and verify `public.tweets_cache` rows plus `cron.job_run_details` success entries.
