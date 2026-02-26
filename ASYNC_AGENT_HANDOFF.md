# Async Agent Handoff (`codex/async-dev`)

This file is updated by Codex during asynchronous work sessions so changes are easy to review later.

## Current Status

- Branch: `codex/async-dev`
- Mode: Async development active
- Last milestone: Supabase cron validation pass + syncTweets gateway auth/header fix follow-up

## Latest Milestone

### Summary

- Took the recommended Supabase validation step for external-feed cron sync and confirmed the remote project is currently not scheduling `sync_tweets_cache_30m`: `cron` and `net` schemas/extensions are absent, `app.settings.supabase_url` / `app.settings.sync_tweets_webhook_secret` are unset, and `public.tweets_cache` has no rows.
- Redeployed Supabase Edge Function `syncTweets` from `codex/async-dev` after moving `verify_jwt = false` into root `supabase/config.toml` (the deploy path did not honor the per-function `config.toml` file).
- Live endpoint probes showed the Supabase Edge gateway still requires `Authorization`/`apikey` headers even with `verify_jwt = false` (error changed from `Missing authorization header` to `Invalid JWT` when sending dummy headers), so the cron SQL needed a follow-up fix.
- Added a new migration to reschedule `sync_tweets_cache_30m` with `Authorization` + `apikey` headers sourced from `app.settings.supabase_anon_key` (plus existing `x-cron-secret`) when cron/net/settings are available.

### Files Touched

- `supabase/config.toml`
- `supabase/functions/syncTweets/config.toml` (removed; deploy did not use per-function config file)
- `supabase/migrations/20260226163000_fix_sync_tweets_cron_auth_headers.sql`
- `ASYNC_AGENT_HANDOFF.md`

### Migrations Applied

- `20260226163000_fix_sync_tweets_cron_auth_headers.sql` applied via `scripts/supabase-cli.sh db push` (remote emitted notice and no-oped because `cron` extension/schema is still unavailable).

### Verification

- Remote DB checks via `scripts/supabase-psql.sh`:
  - `to_regnamespace('cron') = null`, `to_regnamespace('net') = null`
  - `current_setting('app.settings.supabase_url', true)` unset
  - `current_setting('app.settings.sync_tweets_webhook_secret', true)` unset
  - `public.tweets_cache` row count = `0`
- Edge Function deploy:
  - `scripts/supabase-cli.sh functions deploy syncTweets --project-ref <ref>` succeeded (network-enabled run)
- Supabase migration apply (network-enabled run):
  - `scripts/supabase-cli.sh db push` applied `20260226163000_fix_sync_tweets_cron_auth_headers.sql` and emitted `Skipping syncTweets cron auth-header reschedule: cron schema/extension is unavailable.`
- Edge gateway probes (network-enabled `curl`):
  - no auth headers -> `401 Missing authorization header`
  - dummy `Authorization`/`apikey` headers -> `401 Invalid JWT`
  - confirms root `verify_jwt = false` is not enough by itself for cron; gateway still needs valid auth headers

### Open Risks / Notes

- Cron jobs still cannot be installed on this project until `pg_cron` and `pg_net` are enabled remotely and required `app.settings.*` values are set (at minimum `supabase_url`, and now also `supabase_anon_key`; optionally `sync_tweets_webhook_secret`).
- `.env.supabase.local` in this environment did not include `SUPABASE_ANON_KEY`/`SUPABASE_SERVICE_ROLE_KEY`, so an authenticated live `syncTweets` invoke (and write verification into `tweets_cache`) could not be completed from this run.
- The new auth-header migration is idempotent, but if applied before extensions/settings are present it will no-op and must be rerun manually (or by replaying the scheduling SQL) after infra prerequisites are added.

## Next Recommended Action

- Enable `pg_cron` + `pg_net` on the Supabase project, set `app.settings.supabase_url` and `app.settings.supabase_anon_key` (and `app.settings.sync_tweets_webhook_secret` if using secret-gated cron calls), apply/re-run the new cron auth-header migration scheduling SQL, then validate `sync_tweets_cache_30m` job runs and populates `tweets_cache`.
