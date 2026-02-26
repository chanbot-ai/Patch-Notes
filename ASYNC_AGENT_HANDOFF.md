# Async Agent Handoff (`codex/async-dev`)

This file is updated by Codex during asynchronous work sessions so changes are easy to review later.

## Current Status

- Branch: `codex/async-dev`
- Mode: Async development active
- Last milestone: Release Calendar "Games This Month" spotlight polish (Batch 10)

## Latest Milestone

### Summary

- Added a richer `Games This Month` spotlight board above the calendar grid in `ReleaseCalendarView`, with horizontal cover-art cards for upcoming releases in the selected month.
- Prioritized spotlight card ordering by followed/favorited titles first, then release date, so the top strip reflects the user’s current interests.
- Added compact per-card metadata and quick actions (`Details`, follow toggle, favorite toggle) plus a lightweight social-post count signal using cached hot/following feed posts.
- Kept the existing text agenda below the grid (renamed to `Month Agenda`) so the new visual strip complements rather than replaces the dense list.

### Files Touched

- `PatchNotes/Views/ReleaseCalendarView.swift`
- `ASYNC_AGENT_HANDOFF.md`

### Migrations Applied

- None.

### Verification

- `HOME=/tmp/codex-home-async CLANG_MODULE_CACHE_PATH=/tmp/codex-clang-module-cache SWIFTPM_MODULECACHE_OVERRIDE=/tmp/codex-swiftpm-cache xcodebuild -scheme PatchNotes -destination 'generic/platform=iOS' -configuration Debug -derivedDataPath /tmp/codex-derived-data build` failed in sandbox:
  - CoreSimulator service connection unavailable (expected sandbox limitation)
  - SwiftPM dependency resolution failed because `github.com` DNS/network access is blocked in this environment (`Could not resolve host: github.com`)

### Open Risks / Notes

- New spotlight cards use currently cached `hot` + `following` posts to show a lightweight social-post count; this is intentionally opportunistic and may show `0` until feed data has loaded in-session.

## Next Recommended Action

- In a full Xcode environment, validate the new Release Calendar spotlight strip on iPhone sizes (tap targets + horizontal scrolling) and confirm follow/favorite toggles update the spotlight ordering as expected.
