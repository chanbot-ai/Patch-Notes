# Async Agent Handoff (`codex/async-dev`)

This file is updated by Codex during asynchronous work sessions so changes are easy to review later.

## Current Status

- Branch: `codex/async-dev`
- Mode: Async development active
- Last milestone: Notifications auth/session reliability hotfix (token refresh sync)

## Latest Milestone

### Summary

- Fixed a likely notifications auth desync by syncing `AppStore` on session token changes (not just user ID changes) from `AuthManager`.
- Reset notifications realtime subscription when access tokens rotate and trigger a notifications reload if the view was previously stuck in an auth error state.
- Added notifications auth-error detection with a one-time retry using Supabase's current session snapshot when the stored `AppStore` token is stale.
- Replaced raw notifications load errors with friendlier messaging for expired session/network cases to reduce noisy repeated failure states.

### Files Touched

- `PatchNotes/Model/AppStore.swift`
- `PatchNotes/PatchNotesApp.swift`
- `ASYNC_AGENT_HANDOFF.md`

### Migrations Applied

- None.

### Verification

- `xcodebuild -scheme PatchNotes -destination 'platform=iOS Simulator,name=iPhone 15' -configuration Debug build` failed in sandbox (CoreSimulator unavailable + denied `~/.cache`/SwiftPM manifest cache writes).
- `HOME=/tmp/codex-home ... xcodebuild -scheme PatchNotes -destination 'generic/platform=iOS' -configuration Debug build` also failed in sandbox for the same CoreSimulator/cache permission constraints; no app-level compile diagnostics were emitted before package resolution failure.

### Open Risks / Notes

- `AppStore` now treats auth errors containing `sub` as session-related for notifications; this is intentionally broad for the observed warning pattern but could mask a different backend validation error if one later appears with the same substring.

## Next Recommended Action

- Validate notifications in a full Xcode environment by forcing token expiry / app foreground resume and confirming inbox fetch + realtime subscription recover without repeated `JWT expired` errors.
