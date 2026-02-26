# Async Agent Handoff (`codex/async-dev`)

This file is updated by Codex during asynchronous work sessions so changes are easy to review later.

## Current Status

- Branch: `codex/async-dev`
- Mode: Async development active
- Last milestone: Composer post-create refresh now updates Following feed

## Latest Milestone

### Summary

- Fixed a Following feed activation gap after post creation: the composer success callback now reloads both Hot and Following feeds instead of only Hot.
- This makes newly created game-linked posts appear in the Following tab without requiring a manual pull-to-refresh or tab reload.

### Files Touched

- `PatchNotes/Views/FeedView.swift`
- `ASYNC_AGENT_HANDOFF.md`

### Migrations Applied

- None.

### Verification

- `HOME=/tmp/codex-home-async xcodebuild -scheme PatchNotes -destination 'generic/platform=iOS' -configuration Debug build` failed in sandbox (CoreSimulator service unavailable and denied writes to `~/.cache/clang/ModuleCache` / SwiftPM manifest cache under `~/Library/Caches`), so package resolution did not complete and no app-level compile diagnostics were emitted.

### Open Risks / Notes

- Composer post success now triggers an additional following-feed reload even when the new post is not game-linked or linked to an unfollowed game; this is acceptable for correctness but could be optimized later by returning the created post payload and conditionally updating feed state.

## Next Recommended Action

- In a full Xcode environment, validate that creating a game-linked post immediately appears in the Following tab (especially when the tab is already open) without manual refresh.
