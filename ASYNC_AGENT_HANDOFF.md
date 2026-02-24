# Async Agent Handoff (`codex/async-dev`)

This file is updated by Codex during asynchronous work sessions so changes are easy to review later.

## Current Status

- Branch: `codex/async-dev`
- Mode: Async development active
- Last milestone: Notification inbox polish (read/unread filter + recency grouping)

## Latest Milestone

### Summary

- Added read/unread segmented filter in the notifications inbox.
- Grouped notifications into Today / Yesterday / This Week / Earlier sections.
- Provided empty-state copy for the unread filter.

### Files Touched

- `PatchNotes/Views/FeedView.swift`
- `ASYNC_AGENT_HANDOFF.md`

### Migrations Applied

- None

### Verification

- `xcodebuild -scheme PatchNotes -destination 'platform=iOS Simulator,name=iPhone 15' -configuration Debug build` failed (CoreSimulator connection invalid; SwiftPM/ModuleCache access denied in sandbox).

### Open Risks / Notes

- Filtering happens client-side on the last 50 notifications; no server-side read/unread query yet.

## Next Recommended Action

- Continue open-ended roadmap execution (priority order):
  1. Release Calendar polish tied to follow/watch state and social activity
  2. Social composer/media enrichment (media uploads + richer post types)
