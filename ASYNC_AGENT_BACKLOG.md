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

- [ ] Batch 2 (`%%%`) Client implementation sequence: comment reactions -> comment ranking toggle (`Top/New`) -> comment pagination UX polish -> animated expansion UI -> following feed client wiring (reuse centralized reaction state keyed by post ID)

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

## Parking Lot

- [ ] Nice-to-have items / future ideas
