# Async Agent Backlog

Use this file to queue tasks for asynchronous Codex work on `codex/async-dev`.

## How To Add Work

- Add items under `Queued`
- Include acceptance criteria where possible
- Mark blockers/constraints explicitly

## Queued

- [ ] Batch 1 (`%%%`) Client comments foundation on centralized `AppStore`: top-level comments + 1-level replies + ranked fetch + optimistic insert + realtime reconciliation via `post_metrics` + no per-view state + no N+1 loads (load only in post detail/expanded UI)
- [ ] Batch 2 (`%%%`) Client implementation sequence: comment reactions -> comment ranking toggle (`Top/New`) -> comment pagination -> animated expansion UI -> following feed client wiring (reuse centralized reaction state keyed by post ID)
- [ ] Batch 3 (`%%%`) Advanced social loop: nested reply UI refinement, multi-reaction comment chips, comment sorting polish, notification trigger system (backend+client), architecture stress-test/perf guardrails
- [ ] After attempting as much as feasible from batches above, propose next feature roadmap toward “Sleeper sports app of video games” vision and begin implementing on `codex/async-dev`

## In Progress

- [ ] Open-ended roadmap execution: propose next feature roadmap toward “Sleeper sports app of video games” vision and begin implementing highest-value item(s) on `codex/async-dev`
  - Roadmap priority (current):
    1. Game follow management + game-linked posts (activate Following feed end-to-end)
    2. Notification deep-linking + actor profile display
    3. Public profile joins/views for posts/comments (no N+1)
    4. Social composer/media enrichment + game context chips in feed rows
    5. Release Calendar polish pass tied to follow/watch state and social activity

## Done

- [x] Async workflow scaffolding (`ASYNC_AGENT_*` files) created and branch `codex/async-dev` pushed
- [x] Backend-first comment/following infrastructure migrations applied and verified:
  - enable comment reactions (`reactions.comment_id` + target constraint + comment reaction uniqueness)
  - `comment_metrics` + `post_comments_ranked`
  - `following_feed_view`
  - comments owner delete policy + comment_count decrement trigger support
- [x] Batch 1 (`%%%`) Client comments foundation on centralized `AppStore`:
  - `Comment` model + ranked comments fetch (`post_comments_ranked`)
  - centralized `commentsByPost` state (with paging baseline metadata)
  - optimistic comment insert (top-level + reply)
  - realtime reconciliation via existing `post_metrics` subscription (comment_count change -> refresh loaded comments)
  - on-demand comments UI (sheet) with top-level comments + one-level nested replies
  - no feed-wide comment preloads / no N+1 comment fetches
- [x] Batch 2 (`%%%`) Client implementation sequence:
  - comment reactions (toggle + optimistic, centralized in `AppStore`)
  - comment ranking toggle (`Top` / `New`)
  - pagination UX polish (`load more`, page offsets, cache trim guardrails)
  - animated/collapsible replies UI
  - following feed client wiring (`following_feed_view`, segmented Hot/Following feed in `FeedView`)
- [x] Batch 3 (`%%%`) Advanced social loop (substantial subset implemented):
  - notification trigger system backend (`public.notifications`, comment/reply triggers, RLS, grants, realtime publication)
  - client notifications inbox surface with centralized `AppStore` state + realtime subscription
  - architecture stress-test/perf guardrails:
    - coalesced comment realtime refreshes
    - debounced notifications refresh
    - in-flight post refresh dedupe
    - duplicate reaction toggle request guards (post + comment)
  - nested reply UI refinement / multi-reaction comment chips / comment sorting polish were already largely completed in Batch 2
- [x] Open-ended roadmap tranche 1 (started):
  - centralized backend-synced followed game state in `AppStore`
  - follow/unfollow game mutations against `user_followed_games` (with `games` catalog ensure step)
  - release-detail follow/unfollow control
  - post composer optional linked game picker (`posts.game_id`) to seed Following feed content
- [x] Open-ended roadmap tranche 2:
  - notification actor profile batch hydration via `public_profiles` (no N+1)
  - notification inbox row copy upgraded with actor names when available
  - notification deep-linking into post comments sheet (with fallback post resolution)

## Parking Lot

- [ ] Nice-to-have items / future ideas
