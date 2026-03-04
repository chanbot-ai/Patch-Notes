-- =============================================================================
-- Migration: Per-Game Feed RPC
-- Adds a cursor-paginated function for fetching posts filtered by game_id.
-- Mirrors fetch_hot_feed_page but scoped to a single game.
-- =============================================================================

begin;

-- ── Index for game_id lookups ────────────────────────────────────────

create index if not exists idx_posts_game_id
    on public.posts (game_id);

-- ── Game feed pagination function ────────────────────────────────────

create or replace function public.fetch_game_feed_page(
    p_game_id uuid,
    p_cursor_score double precision default null,
    p_cursor_created_at timestamp without time zone default null,
    p_cursor_id uuid default null,
    p_limit integer default 25
)
returns table (
    id uuid,
    author_id uuid,
    game_id uuid,
    type public.post_type,
    title text,
    body text,
    media_url text,
    thumbnail_url text,
    is_system_generated boolean,
    created_at timestamp without time zone,
    reaction_count integer,
    comment_count integer,
    hot_score double precision,
    author_username text,
    author_display_name text,
    author_avatar_url text,
    author_created_at timestamp without time zone,
    primary_badge_key text,
    secondary_badge_key text,
    badge_confidence_tier text,
    badge_confidence_score double precision,
    badge_assignment_source text,
    badge_assignment_status text,
    badge_assigned_at timestamp without time zone,
    source_kind text,
    source_provider text,
    source_external_id text,
    source_handle text,
    source_url text,
    source_published_at timestamptz
)
language sql stable
as $$
    select
        p.id,
        p.author_id,
        p.game_id,
        p.type,
        p.title,
        p.body,
        p.media_url,
        p.thumbnail_url,
        p.is_system_generated,
        p.created_at,
        m.reaction_count,
        m.comment_count,
        m.hot_score,
        pp.username,
        pp.display_name,
        pp.avatar_url,
        pp.created_at,
        p.primary_badge_key,
        p.secondary_badge_key,
        p.badge_confidence_tier,
        p.badge_confidence_score,
        p.badge_assignment_source,
        p.badge_assignment_status,
        p.badge_assigned_at,
        p.source_kind,
        p.source_provider,
        p.source_external_id,
        p.source_handle,
        p.source_url,
        p.source_published_at
    from public.posts p
    join public.post_metrics m on m.post_id = p.id
    left join public.public_profiles pp on pp.id = p.author_id
    where coalesce(p.game_id, public.game_id_from_primary_badge_key(p.primary_badge_key)) = p_game_id
        and (
            p_cursor_score is null
            or (
                (m.hot_score, p.created_at, p.id) < (p_cursor_score, p_cursor_created_at, p_cursor_id)
                and p.id != p_cursor_id
            )
        )
    order by m.hot_score desc, p.created_at desc, p.id desc
    limit p_limit;
$$;

-- ── Grants ───────────────────────────────────────────────────────────

grant execute on function public.fetch_game_feed_page(uuid, double precision, timestamp without time zone, uuid, integer) to anon;
grant execute on function public.fetch_game_feed_page(uuid, double precision, timestamp without time zone, uuid, integer) to authenticated;

commit;
