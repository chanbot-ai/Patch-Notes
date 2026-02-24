# Async Agent Handoff (`codex/async-dev`)

This file is updated by Codex during asynchronous work sessions so changes are easy to review later.

## Current Status

- Branch: `codex/async-dev`
- Mode: Async development active
- Last milestone: Roadmap tranche 2 (notification deep-linking + actor names) after Following-feed activation tranche

## Latest Milestone

### Summary

- Continued the open-ended roadmap with notification UX loop-closure improvements.
- Notification inbox now batch-hydrates actor profiles via `public_profiles` (no per-row/N+1 fetches).
- Notification rows display actor names when available instead of generic-only copy.
- Tapping a notification now marks it read, dismisses the inbox, and deep-links into the related post’s comments sheet when the post is resolvable.
- Added fallback post resolution for notifications (`FeedService.fetchPost` falls back from `hot_feed_view` to raw `posts`), improving deep-link reliability for low-ranked posts.

### Files Touched

- `PatchNotes/PublicProfileService.swift`
- `PatchNotes/FeedService.swift`
- `PatchNotes/Model/AppStore.swift`
- `PatchNotes/Views/FeedView.swift`
- `ASYNC_AGENT_BACKLOG.md`
- `ASYNC_AGENT_HANDOFF.md`

### Migrations Applied

- None in this milestone (uses existing `games` / `user_followed_games` schema + policies)

### Verification

- `xcodebuild` simulator build succeeded after roadmap tranche changes (`** BUILD SUCCEEDED **`)
- Simulator install + relaunch succeeded (`com.patchnotes.PatchNotes`)
- Compile/runtime wiring checks covered:
  - `PublicProfileService` batched profile fetch by IDs (`public_profiles`)
  - notification actor-profile cache in `AppStore`
  - notification deep-link flow (`FeedView` inbox -> comments sheet)
  - `FeedService.fetchPost` fallback path (`hot_feed_view` -> `posts`)

### Open Risks / Notes

- `games` table is currently permissive (legacy grants / no explicit RLS); current follow/composer game sync uses it as-is for velocity, but hardening is recommended before production.
- Notification deep-links rely on resolving a `Post`; if the referenced post is unavailable (deleted/inaccessible), the tap currently just marks read and stays in the inbox.
- Follow controls are still only surfaced in Release Detail (not yet across calendar cards / My Games rows).
- Following feed usefulness still depends on posts having `game_id`; composer now supports this, but older posts remain unlinked.

## Next Recommended Action

- Continue open-ended roadmap execution (priority order):
  1. Harden `games` table access model (RLS/grants) now that app writes to it
  2. Surface follow/unfollow controls across more game surfaces + show followed badges in feed/composer
  3. Public profile joins/views for posts/comments (no N+1 author fetches)
  4. Feed rows/post detail: show linked game chips and jump-to-game context
