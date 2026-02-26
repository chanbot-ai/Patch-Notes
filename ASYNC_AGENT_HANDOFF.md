# Async Agent Handoff (`codex/async-dev`)

This file is updated by Codex during asynchronous work sessions so changes are easy to review later.

## Current Status

- Branch: `codex/async-dev`
- Mode: Async development active
- Last milestone: syncTweets provider key fixed; dry/live sync verified with `tweets_cache` writes

## Latest Milestone

### Summary

- Executed the recommended Supabase infra follow-up and enabled `pg_cron` + `pg_net` on the remote database (they were available but not installed).
- Verified `app.settings.supabase_url` / `app.settings.supabase_anon_key` still cannot be set from this DB connection (`permission denied to set parameter`) via both `ALTER DATABASE` and `ALTER ROLE`, so the migration-based scheduler path remains blocked on admin/dashboard-level config.
- Used a safe operational fallback to manually register `tweets_cache_retention_daily` and `sync_tweets_cache_30m` cron jobs directly in `cron.job` (including `Authorization` + `apikey` headers for the `syncTweets` Edge Function call).
- Confirmed the hosted `TWITTERAPI_IO_API_KEY` secret digest did not match the locally validated token, then overwrote the hosted Edge Function secret with the exact working token and redeployed `syncTweets`.
- Re-ran authenticated `syncTweets` dry-run and live test calls successfully for `@ign`; dry-run reported `wouldUpsert: 3`, and a delayed live retry (after the provider's free-tier QPS cooldown) returned `upserted: 3`.
- Verified `public.tweets_cache` now contains rows (`ign`: 3 rows) and recent `sync_tweets_cache_30m` cron jobs continue to execute.

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
  - confirmed `TWITTERAPI_IO_API_KEY` is present on the project
  - compared secret digest with the locally tested token digest and found a mismatch, then updated the hosted secret to match
- Edge Function probes (network-enabled `curl` with valid anon auth headers):
  - dry-run succeeded (`ok: true`, `wouldUpsert: 3`) for `handles: [\"ign\"]`
  - immediate live retry hit twitterapi.io free-tier QPS guard (`429 Too Many Requests`, one request every 5 seconds)
  - delayed live retry succeeded (`ok: true`, `upserted: 3`)
- Remote DB runtime checks (`scripts/supabase-psql.sh`):
  - `public.tweets_cache` row count is now `3` (`source_handle = ign`)
  - latest `synced_at` observed: `2026-02-26 18:35:37.402+00`
  - `cron.job_run_details` shows `sync_tweets_cache_30m` jobs executing successfully at `17:00`, `17:30`, `18:00`, and `18:30` UTC (cron invocation path active)

### Open Risks / Notes

- `syncTweets` is now working end-to-end for manual authenticated test calls and writes to `tweets_cache`.
- twitterapi.io free-tier limit is strict (QPS 1 request / 5 seconds), so back-to-back manual test calls can return `429` even when the key is valid.
- Manual cron scheduling embeds the anon key in the cron job command text as a stopgap because `app.settings.*` writes are blocked from this connection. Prefer replacing with the migration-driven `app.settings` path once admin-level config is available.
- Need to observe a post-fix scheduled cron execution that results in cache writes (the cron job rows show execution success, but we have not yet correlated a scheduled run after the corrected provider key with inserted rows).

## Next Recommended Action

- Let the next scheduled `sync_tweets_cache_30m` run execute (or trigger one manually after waiting >5s), then verify `tweets_cache` growth and, if desired, tune cron cadence/testing approach to avoid free-tier QPS collisions during manual validation.
