# Hybrid Feed Architecture Plan (Batch 6)

Date: 2026-02-26
Branch target: `codex/async-dev`

## Decision

Use an "extend current `posts` schema" strategy instead of introducing a new `feed_posts` table.

Reasoning:
- Existing app behavior (feed UI, reactions, comments, realtime refresh, notifications, following feed) is already centered on `public.posts` + `post_metrics` + `Post` decoding.
- A parallel feed table would force a large rewrite of comments/reactions/realtime paths and duplicate ranking/permission logic.
- The new `tweets_cache` path already gives us a safe raw-provider cache. We can project selected cached rows into `posts` for native engagement without exposing provider credentials to the client.

## Current-State Audit (What We Must Preserve)

### Database

- `public.hot_feed_view` and `public.following_feed_view` both select from `public.posts` joined to `public.post_metrics` and now include `public_profiles` joins for author hydration.
- `public.following_feed_view` uses `user_followed_games` + `auth.uid()` filtering (`security_invoker = true`) and is the backend-authoritative membership path for followed games.
- Reactions and comments are keyed to `posts.id` and are already supported by metrics/trigger/realtime flows.
- `public.tweets_cache` + `public.tweets_cache_feed_view` are now available as raw/sanitized external cache layers (read-only for clients).

### Client

- `PatchNotes/Model/Post.swift` decodes feed rows from `hot_feed_view` / `following_feed_view` with optional author/game metadata and powers all feed interactions.
- `FeedService.fetchHotFeed()` / `fetchFollowingFeed()` return `[Post]`; `AppStore` refresh/realtime code assumes post IDs are the canonical identity for reaction/comment reconciliation.
- `FeedView` renders both `Hot` and `Following` from `AppStore.posts` / `AppStore.followingPosts`, so preserving the `Post` model shape minimizes UI churn.

## Target Architecture (Hybrid Without Replacing `posts`)

### Layers

1. Provider cache layer (already started)
- `tweets_cache` stores provider payload snapshots and metadata.
- `syncTweets` handles provider fetches, allowlists, and budget guardrails.

2. Feed projection layer (next implementation tranche)
- Add a projection path that materializes selected external cache rows into `public.posts`.
- External posts are marked as system-generated and tagged with source metadata.
- `post_metrics` / reactions / comments continue to work unchanged because the canonical row is still `posts.id`.

3. Feed presentation layer
- Keep `hot_feed_view` and `following_feed_view` as primary feed query surfaces.
- Extend views with source metadata columns for UI labels/filters (for example `twitter`, `reddit`, `editorial`, `user`).

## Proposed Schema Extensions (Batch 7+)

Add source metadata to `public.posts` (nullable, backward-compatible):
- `source_kind text` (or enum) default `user`
- `source_provider text` nullable (for example `twitterapi.io`, `reddit`)
- `source_external_id text` nullable
- `source_handle text` nullable
- `source_url text` nullable
- `source_published_at timestamptz` nullable
- `source_metadata jsonb not null default '{}'::jsonb`

Indexes / constraints:
- Partial unique index on `(source_provider, source_external_id)` where both are not null
- Index on `source_kind`
- Optional index on `source_published_at desc` for external recency sort experiments

Why on `posts`:
- Enables reuse of existing `post_metrics`, comments, reactions, and realtime subscriptions.
- Avoids a join/mapping layer every time the app needs to open comments or mutate reactions.

## Projection Strategy (Tweets Cache -> Posts)

Create a server-side projection function (SQL function or Edge Function helper) that:
- Reads recent rows from `tweets_cache`
- Maps rows into `posts`
- Derives `game_id` where possible (initially heuristic match by title/handle map; later explicit mapping table)
- Sets `is_system_generated = true`
- Sets `type = 'link'` (or `image` when media cards are desired later)
- Stores source metadata columns and canonical URL
- Upserts idempotently via source unique index

Projection ownership:
- Prefer server-only execution (Supabase function/cron) so the mobile app remains read-only for provider content ingestion.

## UI / Client Plan (Batch 7)

Minimal, non-breaking tranche:
- Extend `Post` decoding to include source metadata columns (all optional).
- Add source label pill in `FeedView` rows (for example `X`, `Reddit`, `Editorial`) with no behavior changes.
- Keep current feed tabs (`Hot`, `Following`) and ranking behavior intact.
- Do not change comment/reaction APIs because projected external content is still a normal `posts` row.

Optional follow-on:
- Source filter chips in `FeedView` after labels are stable.
- Game-specific source preferences and dedupe heuristics at the projection layer.

## Dedupe Strategy

Primary dedupe:
- `(source_provider, source_external_id)` unique on `posts` for projected external rows

Secondary/best-effort dedupe (later):
- Canonical URL normalization
- Similar-body + same-handle + time window checks before projection

Note:
- `tweets_cache` dedupe and `posts` dedupe solve different problems; both should remain.

## Risks / Tradeoffs

- Heuristic `game_id` mapping from tweets may cause false positives/negatives until a mapping table is added.
- Extending `posts` increases row heterogeneity, so view-level column defaults/null handling must stay strict.
- If external feed volume grows materially, ranking and retention for projected rows may need separate policies or source-weight tuning in `hot_feed_view`.

## Batch 7 Implementation Sequence (Recommended)

1. Migration: add `posts` source metadata columns + partial unique index
2. Migration: extend `hot_feed_view` / `following_feed_view` selects with source metadata
3. Server projection path: `tweets_cache` -> `posts` idempotent upsert
4. Client: extend `Post` model decoding
5. Client: source badge rendering in `FeedView`
6. Verification: migration apply, projection dry run, feed queries, reactions/comments on projected rows

## Batch 8 Readiness Notes

Once source-tagged posts exist in the same `posts` pipeline:
- Existing realtime `post_metrics` subscriptions should continue to update rows without new channel wiring.
- Optimistic behavior remains focused on user-created posts only; projected external rows should stay server-authored.
- Remaining Batch 8 work becomes gap-filling (insert membership reconciliation and duplicate event prevention), not a feed-architecture rewrite.
