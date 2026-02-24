# Async Agent Handoff (`codex/async-dev`)

This file is updated by Codex during asynchronous work sessions so changes are easy to review later.

## Current Status

- Branch: `codex/async-dev`
- Mode: Async development active
- Last milestone: Roadmap tranche 4 (follow controls + badges in My Games/social/composer)

## Latest Milestone

### Summary

- Expanded follow/unfollow controls to My Games surfaces and added followed badges in Social + composer.
- Added inline follow pills on Owned and Favorited tiles/rows, plus follow status badges on owned tiles.
- Added followed indicator to Social game chips and composer game picker labels.

### Files Touched

- `PatchNotes/Views/MyGamesView.swift`
- `PatchNotes/Views/SocialView.swift`
- `PatchNotes/Views/FeedView.swift`
- `ASYNC_AGENT_HANDOFF.md`

### Migrations Applied

- None

### Verification

- `xcodebuild -scheme PatchNotes -destination 'platform=iOS Simulator,name=iPhone 15' -configuration Debug build` failed (CoreSimulator connection + sandboxed cache access prevented package resolution).

### Open Risks / Notes

- Follow controls now exist on Release Detail + Release Calendar + My Games surfaces, but not yet in profile surfaces.
- Following feed usefulness still depends on posts having `game_id`; composer now supports this, but older posts remain unlinked.

## Next Recommended Action

- Continue open-ended roadmap execution (priority order):
  1. Public profile joins/views for posts/comments (no N+1 author fetches)
  2. Feed rows/post detail: show linked game chips and jump-to-game context
  3. Notification inbox polish (read/unread filters, grouped by recency)
