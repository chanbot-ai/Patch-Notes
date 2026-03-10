-- ============================================================
-- Step 1.4: Fix tweet projection to assign specialty bot authors
-- ============================================================
-- Changes project_tweets_cache_to_posts to:
-- 1. Resolve bot_user_id from bot_content_sources for Twitter handles
-- 2. Set author_id = bot_user_id (instead of NULL)
-- 3. Set source_kind = 'bot' (instead of 'external')

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
      -- Resolve bot author from bot_content_sources Twitter mappings
      bot.bot_user_id as resolved_bot_author_id,
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
    -- Resolve specialty bot by matching Twitter handle in bot_content_sources
    left join lateral (
      select bcs.bot_user_id
      from public.bot_content_sources bcs
      where bcs.source_type = 'twitter'
        and bcs.is_active = true
        and lower(bcs.source_identifier) in (
          coalesce(c.source_handle, '__no_match__'),
          coalesce(c.author_handle, '__no_match__')
        )
      limit 1
    ) bot on true
  ),
  payload as (
    select
      r.provider,
      r.provider_post_id,
      r.mapped_game_id as game_id,
      r.resolved_bot_author_id as bot_author_id,
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
      p.bot_author_id,  -- Now assigns bot user instead of NULL
      p.game_id,
      'link'::public.post_type,
      null::text,
      p.body,
      p.source_url,
      p.first_media_url,
      true,
      p.projected_created_at,
      'bot',             -- Changed from 'external' to 'bot' for hybrid attribution
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
      author_id = coalesce(excluded.author_id, public.posts.author_id),
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
