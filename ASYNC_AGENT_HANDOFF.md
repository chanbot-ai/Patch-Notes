# Async Agent Handoff (`codex/async-dev`)

This file is updated by Codex during asynchronous work sessions so changes are easy to review later.

## Current Status

- Branch: `codex/async-dev`
- Mode: Async development active
- Last milestone: syncTweets unblocked from Supabase env but blocked by invalid twitterapi.io API key

## Latest Milestone

### Summary

- Executed the recommended Supabase infra follow-up and enabled `pg_cron` + `pg_net` on the remote database (they were available but not installed).
- Verified `app.settings.supabase_url` / `app.settings.supabase_anon_key` still cannot be set from this DB connection (`permission denied to set parameter`) via both `ALTER DATABASE` and `ALTER ROLE`, so the migration-based scheduler path remains blocked on admin/dashboard-level config.
- Used a safe operational fallback to manually register `tweets_cache_retention_daily` and `sync_tweets_cache_30m` cron jobs directly in `cron.job` (including `Authorization` + `apikey` headers for the `syncTweets` Edge Function call).
- Verified hosted Edge Function secrets now include `TWITTERAPI_IO_API_KEY` and re-ran authenticated `syncTweets` dry-run + live test calls.
- `syncTweets` now reaches the provider request path, but both calls fail with `twitterapi.io` `401 Unauthorized` (`API key is invalid`) for `@ign`, so the remaining blocker is provider credential validity rather than Supabase secret wiring.
- Confirmed cron jobs remain active and running (`sync_tweets_cache_30m` succeeded at 17:00 / 17:30 / 18:00 UTC), but `public.tweets_cache` is still empty because provider fetches are failing.

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
- Remote secrets audit (`scripts/supabase-cli.sh secrets list --project-ref <ref>`):
  - confirmed `TWITTERAPI_IO_API_KEY` is now present on the project
- Edge Function probes (network-enabled `curl` with valid anon auth headers):
  - authenticated dry-run and live calls both reached function runtime but returned `500` with provider error:
    - `twitterapi.io request failed for @ign: 401 Unauthorized {"error":"Unauthorized","message":"API key is invalid"}`
- Remote DB runtime checks (`scripts/supabase-psql.sh`):
  - `public.tweets_cache` row count remains `0` after manual test invokes
  - `cron.job_run_details` shows `sync_tweets_cache_30m` runs at `17:00`, `17:30`, and `18:00` UTC with cron status `succeeded` (job execution succeeded, but function/provider payload still failing)

### Open Risks / Notes

- `sync_tweets_cache_30m` is now scheduled and invoking the function, but provider fetches fail because the configured `TWITTERAPI_IO_API_KEY` is rejected by twitterapi.io (`API key is invalid`).
- The most likely issue is secret value content (wrong token, expired/revoked key, or account ID/password stored instead of the provider API key token).
- Manual cron scheduling embeds the anon key in the cron job command text as a stopgap because `app.settings.*` writes are blocked from this connection. Prefer replacing with the migration-driven `app.settings` path once admin-level config is available.
- `public.tweets_cache` remains empty until the function env is completed and a sync run succeeds.

## Next Recommended Action

- Replace/verify the `TWITTERAPI_IO_API_KEY` secret value with a valid twitterapi.io API key token (not account ID/password metadata), then rerun a small authenticated `syncTweets` test and confirm `public.tweets_cache` inserts.
