# Async Agent Handoff (`codex/async-dev`)

This file is updated by Codex during asynchronous work sessions so changes are easy to review later.

## Current Status

- Branch: `codex/async-dev`
- Mode: Async development active
- Last milestone: Batch 1 client comments foundation implemented on centralized `AppStore`

## Latest Milestone

### Summary

- Implemented Batch 1 client comments foundation on top of the new backend + centralized `AppStore`.
- Comments now load on demand only (post comments sheet open), not during feed load.
- Added top-level comments + one-level nested replies UI, optimistic comment insert, and realtime reconciliation through the existing `post_metrics` subscription path.
- Kept feed/reactions architecture centralized in `AppStore` (no per-view comment arrays, no duplicate subscriptions).

### Files Touched

- `PatchNotes/Model/Post.swift`
- `PatchNotes/FeedService.swift`
- `PatchNotes/Model/AppStore.swift`
- `PatchNotes/Views/FeedView.swift`
- `ASYNC_AGENT_WORKFLOW.md`
- `ASYNC_AGENT_BACKLOG.md`
- `ASYNC_AGENT_HANDOFF.md`

### Migrations Applied

- None in this milestone (uses prior backend-first comment/following migrations)

### Verification

- `xcodebuild` simulator build succeeded after client changes (`** BUILD SUCCEEDED **`)
- Simulator app relaunch succeeded (`xcrun simctl launch ... com.patchnotes.PatchNotes`)
- Compile checks covered:
  - `Comment` model decode from `post_comments_ranked`
  - `FeedService` ranked comments fetch + comment insert APIs
  - `AppStore` centralized comments state/optimistic insert/realtime refresh path
  - `FeedView` comments sheet UI + nested replies rendering

### Open Risks / Notes

- No dedicated comment-detail/reaction error toast yet (comment insert failures currently rollback + console print only).
- Pagination backend wiring exists in `AppStore` (`loadMoreComments` + offsets/page size), but UX polish for paging controls/sort toggles belongs to Batch 2.
- Comment rows currently avoid author/profile fetches (intentional to prevent N+1 until public profile join/view strategy is chosen).
- `following_feed_view` backend exists, but client wiring is deferred to Batch 2.

## Next Recommended Action

- Start Batch 2 client work in the requested order:
  - comment reactions (toggle + optimistic, centralized in `AppStore`)
  - comment ranking toggle (`Top` / `New`)
  - pagination UX polish
  - animated expansion UI
  - following feed client wiring using existing `following_feed_view`
