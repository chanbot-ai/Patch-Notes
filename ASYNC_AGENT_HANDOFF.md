# Async Agent Handoff (`codex/async-dev`)

This file is updated by Codex during asynchronous work sessions so changes are easy to review later.

## Current Status

- Branch: `codex/async-dev`
- Mode: Async development active
- Last milestone: Roadmap tranche 3 (games-table hardening + broader follow controls)

## Latest Milestone

### Summary

- Continued the open-ended roadmap with backend hardening + follow-surface expansion.
- Added a migration to harden `public.games` (RLS enabled, explicit `SELECT`/`INSERT`/`UPDATE` policy set, legacy broad grants removed).
- Verified `public.games` now has only the intended privileges:
  - `anon`: `SELECT`
  - `authenticated`: `SELECT`, `INSERT`, `UPDATE`
- Added follow/unfollow controls directly to Release Calendar cards (in addition to Release Detail), reducing friction for populating the Following feed.

### Files Touched

- `PatchNotes/Views/ReleaseCalendarView.swift`
- `supabase/migrations/20260224065610_harden_games_table_access.sql`
- `ASYNC_AGENT_BACKLOG.md`
- `ASYNC_AGENT_HANDOFF.md`

### Migrations Applied

- `20260224065610_harden_games_table_access.sql`
  - enables RLS on `public.games`
  - adds explicit `SELECT` (public) and `INSERT`/`UPDATE` (authenticated) policies
  - tightens `anon`/`authenticated` grants to remove legacy broad privileges

### Verification

- `supabase db push` applied `games` hardening migration cleanly
- Live DB verification completed for `public.games`:
  - RLS enabled
  - policies present (public `SELECT`, authenticated `INSERT`/`UPDATE`)
  - grants reduced to intended surface
- `xcodebuild` simulator build succeeded after Release Calendar follow UI patch (`** BUILD SUCCEEDED **`)

### Open Risks / Notes

- Notification deep-links rely on resolving a `Post`; if the referenced post is unavailable (deleted/inaccessible), the tap currently just marks read and stays in the inbox.
- Follow controls now exist on Release Detail + Release Calendar cards, but not yet in My Games rows / profile surfaces.
- Following feed usefulness still depends on posts having `game_id`; composer now supports this, but older posts remain unlinked.

## Next Recommended Action

- Continue open-ended roadmap execution (priority order):
  1. Surface follow/unfollow controls across more game surfaces + show followed badges in feed/composer
  2. Public profile joins/views for posts/comments (no N+1 author fetches)
  3. Feed rows/post detail: show linked game chips and jump-to-game context
  4. Notification inbox polish (read/unread filters, grouped by recency)
