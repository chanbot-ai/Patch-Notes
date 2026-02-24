# Async Agent Handoff (`codex/async-dev`)

This file is updated by Codex during asynchronous work sessions so changes are easy to review later.

## Current Status

- Branch: `codex/async-dev`
- Mode: Async development active
- Last milestone: Roadmap tranche 6 (linked game chips for feed + detail)

## Latest Milestone

### Summary

- Added batched game catalog hydration for post-linked game IDs.
- Displayed linked game chips in feed rows and post detail headers with navigation to game detail.
- Reused the existing game detail surface for feed-linked game context.

### Files Touched

- `PatchNotes/FeedService.swift`
- `PatchNotes/Model/AppStore.swift`
- `PatchNotes/Views/FeedView.swift`
- `ASYNC_AGENT_HANDOFF.md`

### Migrations Applied

- None

### Verification

- `xcodebuild -scheme PatchNotes -destination 'platform=iOS Simulator,name=iPhone 15' -configuration Debug build` failed (CoreSimulator connection invalid; SwiftPM cache access denied).

### Open Risks / Notes

- Public profile display depends on `public_profiles` view; posts/comments from users without completed profiles may show no author label.

## Next Recommended Action

- Continue open-ended roadmap execution (priority order):
  1. Notification inbox polish (read/unread filters, grouped by recency)
  2. Release Calendar polish tied to follow/watch state and social activity
  3. Social composer/media enrichment (media uploads + richer post types)
