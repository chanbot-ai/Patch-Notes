begin;

create or replace function public.derive_post_badge_assignment_v1(
  p_game_id uuid,
  p_title text,
  p_body text,
  p_media_url text
) returns table (
  primary_badge_key text,
  badge_assignment_source text,
  badge_confidence_tier text,
  badge_confidence_score double precision
)
language plpgsql
as $$
declare
  normalized_text text;
  normalized_media_url text;
  has_any_content boolean;
begin
  if p_game_id is not null then
    return query
    select
      'game:' || lower(p_game_id::text),
      'attachment',
      'high',
      0.95::double precision;
    return;
  end if;

  normalized_text := trim(
    regexp_replace(
      lower(coalesce(p_title, '') || ' ' || coalesce(p_body, '')),
      '\s+',
      ' ',
      'g'
    )
  );
  normalized_media_url := lower(coalesce(p_media_url, ''));
  has_any_content := normalized_text <> '' or btrim(normalized_media_url) <> '';

  if not has_any_content then
    return query
    select 'unspecified', 'text_rules', 'none', 0.10::double precision;
    return;
  end if;

  if normalized_text like '%what are you playing%'
     or normalized_text like '%what are yall playing%'
     or normalized_text like '%what are you all playing%'
     or normalized_text like '%which game%'
     or normalized_text like '%tier list%'
     or normalized_text like '%top 5 games%'
     or normalized_text like '%top five games%'
     or normalized_text like '%favorite games%'
     or normalized_text like '%best games%'
     or normalized_text like '%games are%'
     or normalized_text like '% vs %'
     or normalized_text like '% versus %' then
    return query
    select 'multi_game', 'text_rules', 'medium', 0.70::double precision;
    return;
  end if;

  if normalized_text like '%esports%'
     or normalized_text like '%e-sports%'
     or normalized_text like '%tournament%'
     or normalized_text like '%bracket%'
     or normalized_text like '%roster%'
     or normalized_text like '%playoffs%'
     or normalized_text like '%grand finals%'
     or normalized_text like '%major%'
     or normalized_text like '%lan%'
     or normalized_text like '%scrim%' then
    return query
    select 'esports', 'text_rules', 'medium', 0.74::double precision;
    return;
  end if;

  if normalized_text like '%streamer%'
     or normalized_text like '%creator%'
     or normalized_text like '%influencer%'
     or normalized_text like '%youtuber%'
     or normalized_text like '%stream clip%'
     or normalized_text like '%vod%'
     or normalized_text like '%livestream%'
     or normalized_media_url like '%twitch.tv%'
     or normalized_media_url like '%youtube.com%'
     or normalized_media_url like '%youtu.be%' then
    return query
    select 'creator', 'text_rules', 'medium', 0.72::double precision;
    return;
  end if;

  if normalized_text like '%layoff%'
     or normalized_text like '%laid off%'
     or normalized_text like '%acquisition%'
     or normalized_text like '%acquire%'
     or normalized_text like '%publisher%'
     or normalized_text like '%studio%'
     or normalized_text like '%ceo%'
     or normalized_text like '%executive%'
     or normalized_text like '%earnings%'
     or normalized_text like '%union%'
     or normalized_text like '%lawsuit%' then
    return query
    select 'industry', 'text_rules', 'medium', 0.73::double precision;
    return;
  end if;

  if normalized_text like '%steam%'
     or normalized_text like '%xbox%'
     or normalized_text like '%playstation%'
     or normalized_text like '%psn%'
     or normalized_text like '%nintendo%'
     or normalized_text like '%switch%'
     or normalized_text like '%epic games%'
     or normalized_text like '%epic store%'
     or normalized_text like '%discord%'
     or normalized_text like '%game pass%'
     or normalized_media_url like '%store.steampowered.com%'
     or normalized_media_url like '%steamcommunity.com%'
     or normalized_media_url like '%playstation.com%'
     or normalized_media_url like '%xbox.com%'
     or normalized_media_url like '%nintendo.com%'
     or normalized_media_url like '%epicgames.com%' then
    return query
    select 'platform', 'text_rules', 'medium', 0.72::double precision;
    return;
  end if;

  if normalized_text like '%gamescom%'
     or normalized_text like '%summer game fest%'
     or normalized_text like '%the game awards%'
     or normalized_text like '%state of play%'
     or normalized_text like '%nintendo direct%'
     or normalized_text like '%xbox showcase%'
     or normalized_text like '%showcase%'
     or normalized_text like '%announcement event%'
     or normalized_text like '%convention%' then
    return query
    select 'event', 'text_rules', 'medium', 0.71::double precision;
    return;
  end if;

  if normalized_text like '%game%'
     or normalized_text like '%gaming%'
     or normalized_text like '%gamer%'
     or normalized_media_url <> '' then
    return query
    select 'general_gaming', 'text_rules', 'low', 0.45::double precision;
    return;
  end if;

  return query
  select 'unspecified', 'text_rules', 'none', 0.20::double precision;
end;
$$;

create or replace function public.apply_default_post_badge_assignment()
returns trigger
language plpgsql
as $$
declare
  derived_primary_badge_key text;
  derived_source text;
  derived_confidence_tier text;
  derived_confidence_score double precision;
begin
  if coalesce(nullif(btrim(new.badge_assignment_status), ''), '') = 'user_overridden' then
    new.badge_assigned_at := coalesce(new.badge_assigned_at, now());
    return new;
  end if;

  if new.primary_badge_key is null or btrim(new.primary_badge_key) = '' then
    select
      d.primary_badge_key,
      d.badge_assignment_source,
      d.badge_confidence_tier,
      d.badge_confidence_score
    into
      derived_primary_badge_key,
      derived_source,
      derived_confidence_tier,
      derived_confidence_score
    from public.derive_post_badge_assignment_v1(
      new.game_id,
      new.title,
      new.body,
      new.media_url
    ) d;

    new.primary_badge_key := coalesce(derived_primary_badge_key, 'unspecified');
    new.badge_assignment_source := coalesce(nullif(btrim(new.badge_assignment_source), ''), derived_source, 'text_rules');
    new.badge_confidence_tier := coalesce(nullif(btrim(new.badge_confidence_tier), ''), derived_confidence_tier, 'none');
    new.badge_confidence_score := coalesce(new.badge_confidence_score, derived_confidence_score, 0.20);
  else
    new.badge_assignment_source := coalesce(nullif(btrim(new.badge_assignment_source), ''), 'user');
    new.badge_confidence_tier := coalesce(nullif(btrim(new.badge_confidence_tier), ''), 'medium');
    new.badge_confidence_score := coalesce(new.badge_confidence_score, 0.75);
  end if;

  new.badge_assignment_status := coalesce(nullif(btrim(new.badge_assignment_status), ''), 'assigned');
  new.badge_assigned_at := coalesce(new.badge_assigned_at, now());

  return new;
end;
$$;

with derived as (
  select
    p.id,
    d.primary_badge_key,
    d.badge_assignment_source,
    d.badge_confidence_tier,
    d.badge_confidence_score
  from public.posts p
  cross join lateral public.derive_post_badge_assignment_v1(
    p.game_id,
    p.title,
    p.body,
    p.media_url
  ) d
  where coalesce(nullif(btrim(p.badge_assignment_status), ''), 'assigned') <> 'user_overridden'
)
update public.posts p
set
  primary_badge_key = d.primary_badge_key,
  badge_assignment_source = coalesce(nullif(btrim(p.badge_assignment_source), ''), d.badge_assignment_source),
  badge_confidence_tier = d.badge_confidence_tier,
  badge_confidence_score = d.badge_confidence_score,
  badge_assignment_status = coalesce(nullif(btrim(p.badge_assignment_status), ''), 'assigned'),
  badge_assigned_at = coalesce(p.badge_assigned_at, now())
from derived d
where p.id = d.id
  and (
    p.primary_badge_key is null
    or btrim(p.primary_badge_key) = ''
    or p.primary_badge_key in ('general_gaming', 'unspecified')
    or (
      coalesce(nullif(btrim(p.badge_assignment_source), ''), 'text_rules') in ('text_rules', 'async_enrichment')
      and p.primary_badge_key not like 'game:%'
    )
  );

commit;
