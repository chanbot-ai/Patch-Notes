# Async Agent Handoff (`codex/async-dev`)

This file is updated by Codex during asynchronous work sessions so changes are easy to review later.

## Current Status

- Branch: `codex/async-dev`
- Mode: Async development active
- Last milestone: multi-handle cron scheduling tuned and verified on a real `*/30` run

## Latest Milestone

### Summary

- Added a configurable inter-request delay to `syncTweets` (`TWITTER_SYNC_MIN_REQUEST_INTERVAL_MS`) so multi-handle cron/default runs can stay under twitterapi.io free-tier QPS limits.
- Set and deployed multi-handle scheduling defaults/secrets for cron validation:
  - `TWITTER_SYNC_ALLOWED_HANDLES=ign,xbox,playstation,nintendoamerica`
  - `TWITTER_SYNC_SOURCE_FILTER_HANDLES=ign,xbox,playstation,nintendoamerica`
  - `TWITTER_SYNC_DEFAULT_MAX_HANDLES_PER_RUN=4`
  - `TWITTER_SYNC_MIN_REQUEST_INTERVAL_MS=5500`
- Verified a default no-handles live `syncTweets` call (same mode cron uses) now succeeds with request spacing; initial run upserted `60` rows across `ign/xbox/playstation`, revealing the provider returns `20` tweets per handle regardless of the requested count and the previous default total budget (`60`) truncated the 4th handle.
- Increased `TWITTER_SYNC_DEFAULT_MAX_TOTAL_TWEETS_PER_RUN` to `80`, redeployed `syncTweets`, and then verified the real scheduled `19:00 UTC` `sync_tweets_cache_30m` run populated the 4th handle (`nintendoamerica`), bringing `tweets_cache` to `80` rows total.

### Files Touched

- `supabase/functions/syncTweets/index.ts`
- `ASYNC_AGENT_HANDOFF.md`

### Migrations Applied

- No new repo migration this run.
- Remote status unchanged: cron jobs are still the manually registered fallback (`sync_tweets_cache_30m` / `tweets_cache_retention_daily`) because `app.settings.*` writes remain permission-blocked from this connection.

### Verification

- Function deploy + config validation:
  - deployed updated `syncTweets` after adding request spacing support in `supabase/functions/syncTweets/index.ts`
  - hosted secrets now include multi-handle defaults + spacing (`TWITTER_SYNC_ALLOWED_HANDLES`, `TWITTER_SYNC_SOURCE_FILTER_HANDLES`, `TWITTER_SYNC_DEFAULT_MAX_HANDLES_PER_RUN=4`, `TWITTER_SYNC_MIN_REQUEST_INTERVAL_MS=5500`, later `TWITTER_SYNC_DEFAULT_MAX_TOTAL_TWEETS_PER_RUN=80`)
- Default no-handles live invocation (cron-equivalent mode) via authenticated `curl`:
  - returned `ok: true`
  - used default handles: `ign`, `xbox`, `playstation`, `nintendoamerica`
  - respected `requestSpacingMs: 5500`
  - initial run upserted `60` rows and stopped at the prior default `maxTotalTweets=60`
- Budget tuning follow-up:
  - set `TWITTER_SYNC_DEFAULT_MAX_TOTAL_TWEETS_PER_RUN=80` and redeployed `syncTweets`
- Real scheduled-run verification (`cron.job_run_details` + cache state):
  - `sync_tweets_cache_30m` executed at `2026-02-26 19:00:00 UTC` (cron status `succeeded`)
  - `tweets_cache` grew from `60` rows to `80` rows by `2026-02-26 19:00:05.384+00`
  - per-handle rows after scheduled run:
    - `ign`: 20
    - `xbox`: 20
    - `playstation`: 20
    - `nintendoamerica`: 20
- Manual cron-SQL-path nuance remains:
  - `net._http_response` can time out at 5000ms while the Edge Function still completes and writes rows to `tweets_cache`

### Open Risks / Notes

- `syncTweets` is now working for scheduled/default cron runs and writes to `tweets_cache`.
- Provider behavior currently ignores the requested `count` parameter for these calls and returns `20` tweets per handle; budgeting must assume `~20` rows per handle unless/until provider behavior changes.
- `net.http_post` default response wait can time out at 5000ms while the downstream function still completes successfully; inspect `tweets_cache`/`synced_at` before treating `net._http_response` timeout rows as sync failures.
- Manual cron scheduling still embeds the anon key in the cron job command text as a stopgap because `app.settings.*` writes are blocked from this connection. Prefer replacing with the migration-driven `app.settings` path once admin-level config is available.

## Next Recommended Action

- Expand/tune the production source allowlist and per-run budgets (now that higher credits are available), then continue Batch 7 hybrid feed implementation using the verified `tweets_cache` cron pipeline as the external-source input.

## Merge Milestone (2026-02-26)

### Summary

- Merged `main` (`c6e3583`, media sizing + tap-target improvements) into `codex/async-dev`.
- Resolved the only merge conflict in `PatchNotes.xcodeproj/project.pbxproj` by preserving async badge file entries and re-adding `MatchDetailView.swift` with fresh Xcode object IDs (`...29` file ref / `...4C` build file) to avoid ID collisions.
- `PatchNotes/Views/FeedView.swift` and `PatchNotes/Model/AppStore.swift` auto-merged cleanly.

### Verification

- Confirmed merged source includes both:
  - main-side feed media sizing/cropping/tap-target changes (`RemoteImageAspectRatioProbe`, `RemoteMediaImage(contentMode: .fit)` in `FeedView` / `AppStyles`)
  - async-side following-feed refresh after compose (`store.loadFollowingFeed()` callback path)
- `xcodebuild` simulator Debug build succeeded after merge:
  - `xcodebuild -project PatchNotes.xcodeproj -scheme PatchNotes -configuration Debug -destination id=DEA2BE7C-8B5C-4D57-8648-625511A4F6D8 -derivedDataPath /tmp/PatchNotesDerived CODE_SIGNING_ALLOWED=NO build`
- Installed + launched merged app in booted simulator:
  - `xcrun simctl install booted /tmp/PatchNotesDerived/Build/Products/Debug-iphonesimulator/PatchNotes.app`
  - `xcrun simctl launch booted com.patchnotes.PatchNotes` (PID `78969`)

### Notes

- No Supabase migrations or remote config changes were applied in this merge-only step.
