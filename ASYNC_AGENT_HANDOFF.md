# Async Agent Handoff (`codex/async-dev`)

This file is updated by Codex during asynchronous work sessions so changes are easy to review later.

## Current Status

- Branch: `codex/async-dev`
- Mode: Async development active
- Last milestone: Backend-first comment/following feed foundation migrations applied + verified

## Latest Milestone

### Summary

- Implemented and applied the requested backend-first migration batch for comment reactions, comment metrics/ranking, and following feed.
- Fixed/closed Step 0 backend gaps discovered during audit:
  - `comments` owner delete RLS policy was missing
  - `comments` trigger path was not delete-aware for `post_metrics.comment_count`
  - comments table contract expected non-null `post_id` / `user_id`
- Added verification smoke tests (transactional, rolled back) for:
  - post reaction insert/delete
  - comment insert/delete (with `post_metrics.comment_count` updates)
  - comment reaction insert/delete (with `post_comments_ranked.reaction_count` updates)

### Files Touched

- `supabase/migrations/20260224052842_extend_reactions_for_comments.sql`
- `supabase/migrations/20260224052843_create_comment_metrics_and_ranking.sql`
- `supabase/migrations/20260224052844_create_following_feed_view.sql`
- `ASYNC_AGENT_WORKFLOW.md`
- `ASYNC_AGENT_BACKLOG.md`
- `ASYNC_AGENT_HANDOFF.md`

### Migrations Applied

- `20260224052842` `extend_reactions_for_comments`
- `20260224052843` `create_comment_metrics_and_ranking`
- `20260224052844` `create_following_feed_view`

### Verification

- `supabase migration list` local/remote aligned through `20260224052844`
- Verified new objects exist:
  - `public.comment_metrics`
  - `public.post_comments_ranked`
  - `public.following_feed_view`
- Verified reactions schema/policies:
  - `reactions.comment_id` added
  - `reaction_target_check` present
  - comment-target unique index present
  - post reaction insert/delete policies remain authenticated-only
- Verified comment/user_followed_games policies:
  - `comments` insert/delete owner policies present
  - `user_followed_games` insert/select/delete owner policies present for following feed
- Verified trigger set:
  - comment insert/delete -> `update_post_metrics_on_comment`
  - comment insert -> `create_comment_metrics_row`
  - comment reaction insert/delete -> `update_comment_metrics`
- Transactional smoke test (rolled back) confirmed:
  - comment_count `0 -> 1 -> 0`
  - ranked comment reaction_count `0 -> 1 -> 0`

### Open Risks / Notes

- `following_feed_view` backend exists, but client wiring is not implemented yet.
- Comment client features are not implemented yet (fetch/pagination/replies/reactions UI).
- `comments` table still allows public `SELECT` (intentional current behavior per existing policy).
- Keep backend and client work separated by your `%%%` batch boundaries to avoid overscoping.

## Next Recommended Action

- Start Batch 1 client layer on top of the new backend foundation:
  - `Comment` model + ranked/paginated fetch in `FeedService`
  - centralized `AppStore.commentsByPost`
  - optimistic comment insert + realtime reconciliation hook
  - no comment preloading on feed list (load on post detail/expand only)
