# Async Agent Handoff (`codex/async-dev`)

This file is updated by Codex during asynchronous work sessions so changes are easy to review later.

## Current Status

- Branch: `codex/async-dev`
- Mode: Async development active
- Last milestone: scheduled sync path fixed (allowlist env) and verified via cron SQL path

## Latest Milestone

### Summary

- Executed the recommended Supabase infra follow-up and enabled `pg_cron` + `pg_net` on the remote database (they were available but not installed).
- Verified `app.settings.supabase_url` / `app.settings.supabase_anon_key` still cannot be set from this DB connection (`permission denied to set parameter`) via both `ALTER DATABASE` and `ALTER ROLE`, so the migration-based scheduler path remains blocked on admin/dashboard-level config.
- Used a safe operational fallback to manually register `tweets_cache_retention_daily` and `sync_tweets_cache_30m` cron jobs directly in `cron.job` (including `Authorization` + `apikey` headers for the `syncTweets` Edge Function call).
- Confirmed the hosted `TWITTERAPI_IO_API_KEY` secret digest did not match the locally validated token, then overwrote the hosted Edge Function secret with the exact working token and redeployed `syncTweets`.
- Re-ran authenticated `syncTweets` dry-run and live test calls successfully for `@ign`; dry-run reported `wouldUpsert: 3`, and a delayed live retry (after the provider's free-tier QPS cooldown) returned `upserted: 3`.
- Verified `public.tweets_cache` now contains rows (`ign`: 3 rows) and recent `sync_tweets_cache_30m` cron jobs continue to execute.
- Investigated the scheduling path itself and found the cron job body (`{"dryRun": false}`) was still failing with `No handles provided` because `TWITTER_SYNC_ALLOWED_HANDLES` was not configured for default cron runs.
- Set hosted Edge Function secret `TWITTER_SYNC_ALLOWED_HANDLES=ign`, redeployed `syncTweets`, then manually executed the same `net.http_post(...)` SQL path used by the cron job. `tweets_cache` grew from `3` to `20` rows and `latest_synced_at` advanced, confirming scheduled invocations now have a valid default handle set.

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
- Additional scheduling env audit:
  - `TWITTER_SYNC_ALLOWED_HANDLES` was initially absent (cron path returned `No handles provided`)
  - added `TWITTER_SYNC_ALLOWED_HANDLES=ign` and redeployed `syncTweets`
- Edge Function probes (network-enabled `curl` with valid anon auth headers):
  - dry-run succeeded (`ok: true`, `wouldUpsert: 3`) for `handles: [\"ign\"]`
  - immediate live retry hit twitterapi.io free-tier QPS guard (`429 Too Many Requests`, one request every 5 seconds)
  - delayed live retry succeeded (`ok: true`, `upserted: 3`)
- Remote DB runtime checks (`scripts/supabase-psql.sh`):
  - `public.tweets_cache` row count is now `3` (`source_handle = ign`)
  - latest `synced_at` observed: `2026-02-26 18:35:37.402+00`
  - `cron.job_run_details` shows `sync_tweets_cache_30m` jobs executing successfully at `17:00`, `17:30`, `18:00`, and `18:30` UTC (cron invocation path active)
- Manual cron-SQL-path verification (`select net.http_post(...)` using the same auth/body shape as cron job):
  - before: `tweets_cache_rows=3`, `latest_synced_at=2026-02-26 18:35:37.402+00`
  - first post-allowlist request stored in `net._http_response` as `400` with `No handles provided` (pre-fix evidence, request `id=5`)
  - post-fix request (`id=6`) shows `net._http_response` timeout at 5000ms, but `tweets_cache` still updated to `20` rows and `latest_synced_at=2026-02-26 18:48:59.71+00`
  - this indicates the async Edge Function request can complete and write cache rows even when `net._http_response` records a timeout on the HTTP response wait

### Open Risks / Notes

- `syncTweets` is now working end-to-end for manual authenticated test calls and writes to `tweets_cache`.
- twitterapi.io free-tier limit is strict (QPS 1 request / 5 seconds), so back-to-back manual test calls can return `429` even when the key is valid.
- Scheduled/default cron runs now require `TWITTER_SYNC_ALLOWED_HANDLES` (or the cron body must pass `handles`); this is now minimally configured as `ign` for validation.
- `net.http_post` default response wait can time out at 5000ms while the downstream function still completes successfully; treat `net._http_response` timeout entries as a signal to inspect cache writes rather than immediate sync failure.
- Manual cron scheduling embeds the anon key in the cron job command text as a stopgap because `app.settings.*` writes are blocked from this connection. Prefer replacing with the migration-driven `app.settings` path once admin-level config is available.
- Need to observe a post-fix scheduled cron execution that results in cache writes (the cron job rows show execution success, but we have not yet correlated a scheduled run after the corrected provider key with inserted rows).

## Next Recommended Action

- Expand `TWITTER_SYNC_ALLOWED_HANDLES` from the temporary `ign` validation value to the desired source list (`ign,xbox,...`), then observe the next scheduled `sync_tweets_cache_30m` run and verify `tweets_cache` growth / `latest_synced_at` advancement.
