# Async Agent Handoff (`codex/async-dev`)

This file is updated by Codex during asynchronous work sessions so changes are easy to review later.

## Current Status

- Branch: `codex/async-dev`
- Mode: Async development active
- Last milestone: Following feed realtime membership reconciliation

## Latest Milestone

### Summary

- Fixed a Following feed realtime gap where newly-created posts for followed games could be missed until manual refresh.
- Added debounced Following feed reconciliation after post realtime updates when the updated post belongs to a followed game and the Following feed has already been loaded in-session.
- Added cleanup/reset for the new pending realtime refresh task and Following-load flag across auth/session changes.

### Files Touched

- `PatchNotes/Model/AppStore.swift`
- `ASYNC_AGENT_HANDOFF.md`

### Migrations Applied

- None.

### Verification

- `xcodebuild -scheme PatchNotes -destination 'platform=iOS Simulator,name=iPhone 15' -configuration Debug build` failed (CoreSimulator service unavailable + sandbox permission denied for Xcode DerivedData/SourcePackages under `~/Library`).
- `xcodebuild -scheme PatchNotes -sdk iphonesimulator -configuration Debug -derivedDataPath /tmp/PatchNotesDerivedData build` progressed past local cache permissions but failed resolving Swift packages because `github.com` DNS/network access is blocked in this sandbox.

### Open Risks / Notes

- Realtime post updates now debounce-refresh the entire Following feed for candidate followed-game posts; this is correctness-first and may be worth narrowing later if update volume becomes high.

## Next Recommended Action

- Run the iOS build in a network-enabled Xcode environment (or with pre-fetched SwiftPM deps) to validate the realtime Following-feed reconciliation path end-to-end.
