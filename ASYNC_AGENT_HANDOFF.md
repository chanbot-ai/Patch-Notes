# Async Agent Handoff (`codex/async-dev`)

This file is updated by Codex during asynchronous work sessions so changes are easy to review later.

## Current Status

- Branch: `codex/async-dev`
- Mode: Async development active
- Last milestone: Following feed CTA + composer game ordering

## Latest Milestone

### Summary

- Added quick navigation CTA buttons when the Following feed is empty, guiding users to the Release Calendar and My Games.
- Prioritized followed games first in the post composer game picker to keep game-linked posts aligned with Following feed usage.

### Files Touched

- `PatchNotes/Views/FeedView.swift`
- `ASYNC_AGENT_HANDOFF.md`

### Migrations Applied

- None.

### Verification

- `xcodebuild -scheme PatchNotes -destination 'platform=iOS Simulator,name=iPhone 15' -configuration Debug build` failed (CoreSimulator connection invalid; sandbox denied ModuleCache/SwiftPM cache access).

### Open Risks / Notes

- None.

## Next Recommended Action

- Run the iOS build in a full Xcode environment to validate the new empty-state navigation and composer ordering.
