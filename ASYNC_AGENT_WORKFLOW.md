# Async Codex Workflow (`codex/async-dev`)

This repo is configured for asynchronous Codex development on branch `codex/async-dev`.

## Goals

- Keep async work isolated from `main`
- Ship in small reviewable commits
- Preserve a clear handoff trail for later review
- Avoid backend/dashboard drift (prefer migrations)

## Branch Policy

- Working branch: `codex/async-dev`
- Commits are made on this branch only unless explicitly directed otherwise
- Push after each completed milestone or logical unit of work

## Delivery Loop (Agentic Work Cadence)

1. Pull latest `codex/async-dev` (if remote moved)
2. Read `ASYNC_AGENT_BACKLOG.md`
3. Pick the highest-priority unblocked item
4. Implement + verify (build/tests/migrations as applicable)
5. Update `ASYNC_AGENT_HANDOFF.md`
6. Commit with a focused message
7. Push branch
8. Move to next unblocked item

## Stop Conditions

Stop and wait for human input when:

- Product behavior is ambiguous
- A destructive action is required
- Secrets/credentials are missing or invalid
- A migration risks data loss
- The fix requires design direction rather than engineering execution

## SQL / Supabase Rules

- Use SQL migrations in `supabase/migrations/` for schema/policy changes
- Verify with linked Supabase project before closing the task
- Do not use service-role key in app code
- Keep local secrets in `.env.supabase.local` (git-ignored)

## Handoff Expectations

Update `ASYNC_AGENT_HANDOFF.md` after each milestone with:

- What changed
- Files touched
- Migration IDs applied (if any)
- Verification performed
- Open risks / next recommended step

