begin;

alter table public.posts
  add column if not exists source_kind text not null default 'user',
  add column if not exists source_provider text,
  add column if not exists source_external_id text,
  add column if not exists source_handle text,
  add column if not exists source_url text,
  add column if not exists source_published_at timestamp with time zone,
  add column if not exists source_metadata jsonb not null default '{}'::jsonb;

update public.posts
set source_kind = 'user'
where source_kind is null or btrim(source_kind) = '';

create index if not exists posts_source_kind_idx
  on public.posts (source_kind);

create index if not exists posts_source_published_at_idx
  on public.posts (source_published_at desc);

create unique index if not exists posts_source_provider_external_id_uidx
  on public.posts (source_provider, source_external_id);

comment on column public.posts.source_kind is
  'Origin class for feed posts (for example user vs external provider projection).';
comment on column public.posts.source_provider is
  'External provider identifier when post is projected from a third-party source.';
comment on column public.posts.source_external_id is
  'Provider-native post identifier used for idempotent projection upserts.';
comment on column public.posts.source_handle is
  'Provider handle/account associated with a projected external post.';
comment on column public.posts.source_url is
  'Canonical URL of the external source post.';
comment on column public.posts.source_published_at is
  'Provider-published timestamp for external content.';
comment on column public.posts.source_metadata is
  'Provider metadata payload subset for projected posts (safe for server-side enrichment and future UI use).';

create table if not exists public.external_source_game_mappings (
  id uuid primary key default gen_random_uuid(),
  source_provider text not null,
  source_handle text not null,
  game_id uuid not null references public.games(id) on delete cascade,
  match_priority integer not null default 100,
  is_active boolean not null default true,
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now(),
  constraint external_source_game_mappings_source_handle_check
    check (btrim(source_handle) <> '')
);

create unique index if not exists external_source_game_mappings_provider_handle_uidx
  on public.external_source_game_mappings (lower(source_provider), lower(source_handle));

create index if not exists external_source_game_mappings_game_id_idx
  on public.external_source_game_mappings (game_id);

alter table public.external_source_game_mappings enable row level security;

revoke all privileges on table public.external_source_game_mappings from anon;
revoke all privileges on table public.external_source_game_mappings from authenticated;
grant select, insert, update, delete on table public.external_source_game_mappings to service_role;

comment on table public.external_source_game_mappings is
  'Server-managed mapping of external source handles (for example X accounts) to PatchNotes games for following-feed projection.';

create or replace function public.project_tweets_cache_to_posts(
  p_limit integer default 200,
  p_lookback interval default interval '7 days'
)
returns table (
  scanned_count integer,
  projected_count integer,
  inserted_count integer,
  updated_count integer
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_limit integer := greatest(coalesce(p_limit, 200), 1);
  v_lookback interval := coalesce(p_lookback, interval '7 days');
begin
  return query
  with candidate_tweets as (
    select
      t.id as tweets_cache_id,
      t.provider,
      t.provider_post_id,
      lower(nullif(btrim(t.source_handle), '')) as source_handle,
      lower(nullif(btrim(t.author_handle), '')) as author_handle,
      nullif(btrim(t.author_name), '') as author_name,
      nullif(btrim(t.author_avatar_url), '') as author_avatar_url,
      nullif(btrim(t.body), '') as body,
      nullif(btrim(t.canonical_url), '') as canonical_url,
      coalesce(t.media_urls, '[]'::jsonb) as media_urls,
      coalesce(t.metrics, '{}'::jsonb) as metrics,
      t.published_at,
      t.synced_at,
      t.created_at,
      t.updated_at
    from public.tweets_cache t
    where t.is_hidden = false
      and coalesce(t.synced_at, t.published_at, t.created_at) >= now() - v_lookback
    order by coalesce(t.synced_at, t.updated_at, t.created_at) desc, t.published_at desc
    limit v_limit
  ),
  resolved as (
    select
      c.*,
      gm.game_id as mapped_game_id,
      coalesce(
        c.canonical_url,
        case
          when coalesce(c.author_handle, c.source_handle) is not null then
            format('https://x.com/%s/status/%s', coalesce(c.author_handle, c.source_handle), c.provider_post_id)
          else null
        end
      ) as resolved_source_url,
      case
        when jsonb_typeof(c.media_urls) = 'array' and jsonb_array_length(c.media_urls) > 0 then
          nullif(btrim(c.media_urls ->> 0), '')
        else null
      end as first_media_url
    from candidate_tweets c
    left join lateral (
      select m.game_id
      from public.external_source_game_mappings m
      where m.is_active = true
        and lower(m.source_provider) = lower(c.provider)
        and lower(m.source_handle) in (
          coalesce(c.source_handle, '__no_match__'),
          coalesce(c.author_handle, '__no_match__')
        )
      order by
        case
          when lower(m.source_handle) = coalesce(c.source_handle, '__no_match__') then 0
          else 1
        end,
        m.match_priority asc,
        m.created_at asc
      limit 1
    ) gm on true
  ),
  payload as (
    select
      r.provider,
      r.provider_post_id,
      r.mapped_game_id as game_id,
      r.body,
      r.first_media_url,
      r.resolved_source_url as source_url,
      coalesce(r.author_handle, r.source_handle) as projected_source_handle,
      r.published_at as source_published_at,
      timezone('UTC', coalesce(r.published_at, now())) as projected_created_at,
      jsonb_strip_nulls(jsonb_build_object(
        'tweets_cache_id', r.tweets_cache_id,
        'author_name', r.author_name,
        'author_avatar_url', r.author_avatar_url,
        'metrics', r.metrics,
        'media_urls', r.media_urls,
        'synced_at', r.synced_at
      )) as projected_source_metadata
    from resolved r
    where r.provider_post_id is not null
  ),
  upserted as (
    insert into public.posts (
      author_id,
      game_id,
      type,
      title,
      body,
      media_url,
      thumbnail_url,
      is_system_generated,
      created_at,
      source_kind,
      source_provider,
      source_external_id,
      source_handle,
      source_url,
      source_published_at,
      source_metadata,
      primary_badge_key,
      badge_assignment_source,
      badge_confidence_tier,
      badge_confidence_score,
      badge_assignment_status,
      badge_assigned_at
    )
    select
      null::uuid,
      p.game_id,
      'link'::public.post_type,
      null::text,
      p.body,
      p.source_url,
      p.first_media_url,
      true,
      p.projected_created_at,
      'external',
      p.provider,
      p.provider_post_id,
      p.projected_source_handle,
      p.source_url,
      p.source_published_at,
      p.projected_source_metadata,
      case
        when p.game_id is not null then 'game:' || lower(p.game_id::text)
        else 'general_gaming'
      end,
      case
        when p.game_id is not null then 'tweet_source_mapping'
        else 'sync_projection'
      end,
      case
        when p.game_id is not null then 'high'
        else 'low'
      end,
      case
        when p.game_id is not null then 0.92
        else 0.45
      end,
      'assigned',
      now()
    from payload p
    on conflict (source_provider, source_external_id)
    do update
    set
      game_id = coalesce(excluded.game_id, public.posts.game_id),
      type = excluded.type,
      title = coalesce(excluded.title, public.posts.title),
      body = coalesce(excluded.body, public.posts.body),
      media_url = coalesce(excluded.media_url, public.posts.media_url),
      thumbnail_url = coalesce(excluded.thumbnail_url, public.posts.thumbnail_url),
      is_system_generated = true,
      created_at = excluded.created_at,
      source_kind = excluded.source_kind,
      source_handle = coalesce(excluded.source_handle, public.posts.source_handle),
      source_url = coalesce(excluded.source_url, public.posts.source_url),
      source_published_at = coalesce(excluded.source_published_at, public.posts.source_published_at),
      source_metadata = excluded.source_metadata,
      primary_badge_key = case
        when excluded.game_id is not null then 'game:' || lower(excluded.game_id::text)
        else public.posts.primary_badge_key
      end,
      badge_assignment_source = case
        when excluded.game_id is not null then 'tweet_source_mapping'
        else coalesce(nullif(btrim(public.posts.badge_assignment_source), ''), 'sync_projection')
      end,
      badge_confidence_tier = case
        when excluded.game_id is not null then 'high'
        else coalesce(nullif(btrim(public.posts.badge_confidence_tier), ''), 'low')
      end,
      badge_confidence_score = case
        when excluded.game_id is not null then greatest(coalesce(public.posts.badge_confidence_score, 0), 0.92)
        else coalesce(public.posts.badge_confidence_score, 0.45)
      end,
      badge_assignment_status = coalesce(nullif(btrim(public.posts.badge_assignment_status), ''), 'assigned'),
      badge_assigned_at = coalesce(public.posts.badge_assigned_at, now())
    returning (xmax = 0) as inserted
  ),
  payload_stats as (
    select count(*)::integer as scanned_count from payload
  ),
  upsert_stats as (
    select
      count(*)::integer as projected_count,
      count(*) filter (where inserted)::integer as inserted_count,
      count(*) filter (where not inserted)::integer as updated_count
    from upserted
  )
  select
    p.scanned_count,
    coalesce(u.projected_count, 0) as projected_count,
    coalesce(u.inserted_count, 0) as inserted_count,
    coalesce(u.updated_count, 0) as updated_count
  from payload_stats p
  left join upsert_stats u on true;
end;
$$;

revoke all privileges on function public.project_tweets_cache_to_posts(integer, interval) from public;
grant execute on function public.project_tweets_cache_to_posts(integer, interval) to service_role;

comment on function public.project_tweets_cache_to_posts(integer, interval) is
  'Projects recent tweets_cache rows into public.posts as idempotent external feed posts (link-type) using optional source->game mappings.';

create or replace view public.hot_feed_view as
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
  pp.username as author_username,
  pp.display_name as author_display_name,
  pp.avatar_url as author_avatar_url,
  pp.created_at as author_created_at,
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
order by m.hot_score desc;

create or replace view public.following_feed_view
with (security_invoker = true) as
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
  pm.reaction_count,
  pm.comment_count,
  pm.hot_score,
  pp.username as author_username,
  pp.display_name as author_display_name,
  pp.avatar_url as author_avatar_url,
  pp.created_at as author_created_at,
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
join public.post_metrics pm on pm.post_id = p.id
join public.user_followed_games ufg
  on ufg.game_id = coalesce(p.game_id, public.game_id_from_primary_badge_key(p.primary_badge_key))
left join public.public_profiles pp on pp.id = p.author_id
where ufg.user_id = auth.uid()
order by pm.hot_score desc;

revoke all privileges on table public.hot_feed_view from anon;
revoke all privileges on table public.hot_feed_view from authenticated;
grant select on table public.hot_feed_view to anon;
grant select on table public.hot_feed_view to authenticated;

revoke all privileges on table public.following_feed_view from anon;
revoke all privileges on table public.following_feed_view from authenticated;
grant select on table public.following_feed_view to authenticated;

commit;
