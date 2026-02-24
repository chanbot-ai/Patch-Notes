# Async Agent Handoff (`codex/async-dev`)

This file is updated by Codex during asynchronous work sessions so changes are easy to review later.

## Current Status

- Branch: `codex/async-dev`
- Mode: Async development active
- Last milestone: Roadmap tranche 5 (public profile hydration for posts/comments)

## Latest Milestone

### Summary

- Added batched public profile hydration for post/comment authors and reused it for notifications.
- Wired author display in feed rows, comment cards, and post detail headers.
- Extended Post model to decode author/game IDs from feed views.

### Files Touched

- `PatchNotes/Model/Post.swift`
- `PatchNotes/FeedService.swift`
- `PatchNotes/Model/AppStore.swift`
- `PatchNotes/Views/FeedView.swift`
- `ASYNC_AGENT_HANDOFF.md`

### Migrations Applied

- None

### Verification

- `xcodebuild -scheme PatchNotes -destination 'platform=iOS Simulator,name=iPhone 15' -configuration Debug build` failed (CoreSimulator connection + sandboxed cache access prevented package resolution).

### Open Risks / Notes

- Public profile display depends on `public_profiles` view; posts/comments from users without completed profiles may show no author label.

## Next Recommended Action

- Continue open-ended roadmap execution (priority order):
  1. Feed rows/post detail: show linked game chips and jump-to-game context
  2. Notification inbox polish (read/unread filters, grouped by recency)
  3. Release Calendar polish tied to follow/watch state and social activity
