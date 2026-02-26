# Async Agent Handoff (`codex/async-dev`)

This file is updated by Codex during asynchronous work sessions so changes are easy to review later.

## Current Status

- Branch: `codex/async-dev`
- Mode: Async development active
- Last milestone: Batch 5 cron + budget guardrails scaffold for `syncTweets`

## Latest Milestone

### Summary

- Started Batch 5 (cron sync + budget guardrails) by extending `supabase/functions/syncTweets` with env-driven per-run caps: `perHandleLimit`, `maxHandles`, and `maxTotalTweets` (with request body overrides clamped to env caps).
- Added source-handle filtering support via `TWITTER_SYNC_SOURCE_FILTER_HANDLES`, combined with `TWITTER_SYNC_ALLOWED_HANDLES`, plus in-run duplicate suppression before the existing idempotent upsert.
- Added richer sync response telemetry (`skippedHandles`, `budgetStopped`, `totalFetched`) to make cron/budget tuning easier during dry runs and first deployments.
- Added a new migration scaffold that creates `public.purge_old_tweets_cache(...)` and attempts idempotent cron scheduling for a 30-minute `syncTweets` call and daily >30d cache cleanup when `cron`/`net` extensions and `app.settings.supabase_url` are available.

### Files Touched

- `supabase/functions/syncTweets/index.ts`
- `supabase/migrations/20260226151000_add_tweets_cache_cron_and_retention.sql`
- `ASYNC_AGENT_BACKLOG.md`
- `ASYNC_AGENT_HANDOFF.md`

### Migrations Applied

- `supabase/migrations/20260226142000_create_tweets_cache_and_feed_view.sql` (created previously, not applied in this sandbox)
- `supabase/migrations/20260226151000_add_tweets_cache_cron_and_retention.sql` (created, not applied in this sandbox)

### Verification

- Backend-only milestone (`supabase` function + SQL migration scaffold); no Swift/iOS files changed, so `xcodebuild` was not rerun.
- Static verification only (sandbox lacks `supabase` CLI / `deno` / `node`, and network is restricted):
  - reviewed `syncTweets` guardrail flow (env parsing, request clamps, handle filtering, total-budget request sizing, in-run dedupe)
  - reviewed migration SQL for retention function permissions and cron scheduling guards/no-op behavior when `cron`/`net`/`app.settings.supabase_url` are unavailable

### Open Risks / Notes

- `syncTweets` uses a best-effort defensive parser for likely `twitterapi.io` response shapes; endpoint path/fields may need adjustment against the actual provider schema during first live run.
- Cron migration assumes Supabase project settings expose `app.settings.supabase_url` (and optionally `app.settings.sync_tweets_webhook_secret`) plus installed `cron`/`net` extensions; if not, it intentionally emits notices and skips scheduling.
- This automation worktree cannot check out `codex/async-dev` directly because that branch is already attached to another local worktree, so work was performed on a detached `HEAD` aligned to `origin/codex/async-dev` and should be pushed back to `codex/async-dev`.
- Live validation is still pending outside sandbox: apply both tweets-cache migrations, deploy `syncTweets`, confirm scheduled jobs, and observe first sync/retention runs.

## Next Recommended Action

- In a full Supabase/dev environment, apply `20260226142000_create_tweets_cache_and_feed_view.sql` and `20260226151000_add_tweets_cache_cron_and_retention.sql`, deploy `syncTweets` with `TWITTERAPI_IO_API_KEY` + `SUPABASE_SERVICE_ROLE_KEY` and the new guardrail envs, confirm cron jobs exist, then run/observe a dry run + first real sync.
