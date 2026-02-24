# Async Agent Handoff (`codex/async-dev`)

This file is updated by Codex during asynchronous work sessions so changes are easy to review later.

## Current Status

- Branch: `codex/async-dev`
- Mode: Async development active
- Last milestone: Roadmap tranche 1 started (game follows + game-linked posts) after Batch 3 checkpoint

## Latest Milestone

### Summary

- Began the open-ended roadmap phase with the highest-leverage item: making the Following feed actually usable end-to-end.
- Added centralized backend-synced followed-game state to `AppStore` (`user_followed_games`), plus optimistic follow/unfollow mutations.
- Added `FeedService` follow/unfollow APIs with a `games` catalog ensure step so follows can succeed without manual DB seeding.
- Added follow/unfollow control to `GameReleaseDetailView` (Release Calendar detail flow).
- Added optional linked-game picker to post composer and writes `posts.game_id`, which enables new posts to appear in `following_feed_view` when users follow that game.
- This directly connects the release calendar/watch behavior to the social feed personalization loop.

### Files Touched

- `PatchNotes/FeedService.swift`
- `PatchNotes/Model/AppStore.swift`
- `PatchNotes/Views/FeedView.swift`
- `PatchNotes/Views/ReleaseCalendarView.swift`
- `ASYNC_AGENT_BACKLOG.md`
- `ASYNC_AGENT_HANDOFF.md`

### Migrations Applied

- None in this milestone (uses existing `games` / `user_followed_games` schema + policies)

### Verification

- `xcodebuild` simulator build succeeded after roadmap tranche changes (`** BUILD SUCCEEDED **`)
- Simulator install + relaunch succeeded (`com.patchnotes.PatchNotes`)
- Compile/runtime wiring checks covered:
  - `FeedService` followed-game fetch/follow/unfollow + `games` catalog ensure helper
  - `AppStore` centralized followed-game state + optimistic follow toggles + following-feed refresh on mutation
  - post composer optional game picker -> `posts.game_id` insert path
  - release detail follow/unfollow UI wiring

### Open Risks / Notes

- `games` table is currently permissive (legacy grants / no explicit RLS); this tranche uses it as-is for velocity, but hardening is recommended before production.
- Release detail now supports follow/unfollow, but follow controls are not yet surfaced across all game surfaces (My Games rows / calendar cards).
- Following feed usefulness still depends on posts having `game_id`; composer now supports this, but older posts remain unlinked.
- Notification inbox exists, but deep-linking + actor profile display are still next in the roadmap.

## Next Recommended Action

- Continue open-ended roadmap execution (priority order):
  1. Notification deep-linking + actor profile display (close engagement loop UX)
  2. Harden `games` table access model (RLS/grants) now that app writes to it
  3. Surface follow/unfollow controls across more game surfaces + show followed badges in feed/composer
  4. Public profile joins/views for posts/comments (no N+1 author fetches)
