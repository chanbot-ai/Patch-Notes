# Async Agent Handoff (`codex/async-dev`)

This file is updated by Codex during asynchronous work sessions so changes are easy to review later.

## Current Status

- Branch: `codex/async-dev`
- Mode: Async development active
- Last milestone: Profile-joined feed/comment views + client cache hydration

## Latest Milestone

### Summary

- Added profile-joined feed/comment views (plus `post_comments_recent`) so feed/comment queries can return author profile fields in one call.
- Extended Post/Comment models to decode author profile columns and hydrated the public profile cache from fetched posts/comments.
- Switched comment “New” fetches to `post_comments_recent` to keep profile fields consistent across sorts.

### Files Touched

- `PatchNotes/FeedService.swift`
- `PatchNotes/Model/AppStore.swift`
- `PatchNotes/Model/Post.swift`
- `supabase/migrations/20260224121000_add_profile_columns_to_feed_views.sql`
- `ASYNC_AGENT_HANDOFF.md`

### Migrations Applied

- `supabase/migrations/20260224121000_add_profile_columns_to_feed_views.sql` (not applied in this environment)

### Verification

- `xcodebuild -scheme PatchNotes -destination 'platform=iOS Simulator,name=iPhone 15' -configuration Debug build` failed (CoreSimulator connection invalid; ModuleCache/SwiftPM access denied in sandbox).

### Open Risks / Notes

- Supabase migration still needs to be applied in a real environment.
- If author profiles are missing from `public_profiles`, client still falls back to the batched profile fetch.

## Next Recommended Action

- Apply the new Supabase migration, then rerun the iOS build in a full Xcode environment.
