begin;

create or replace function public.normalize_game_badge_alias_text(input_text text)
returns text
language sql
immutable
as $$
  select trim(
    regexp_replace(
      lower(coalesce(input_text, '')),
      '[^a-z0-9]+',
      ' ',
      'g'
    )
  );
$$;

create table if not exists public.game_badge_aliases (
  game_id uuid not null references public.games(id) on delete cascade,
  alias text not null,
  normalized_alias text generated always as (public.normalize_game_badge_alias_text(alias)) stored,
  is_ambiguous boolean not null default false,
  is_active boolean not null default true,
  confidence_score double precision not null default 0.88,
  priority integer not null default 100,
  created_at timestamp without time zone not null default now(),
  created_by text,
  notes text,
  primary key (game_id, alias)
);

create index if not exists game_badge_aliases_normalized_alias_idx
  on public.game_badge_aliases (normalized_alias)
  where is_active;

create index if not exists game_badge_aliases_game_id_idx
  on public.game_badge_aliases (game_id);

-- Ensure a canonical OSRS entity exists so text-only OSRS posts can resolve to a game badge.
with existing_osrs as (
  select g.id
  from public.games g
  where public.normalize_game_badge_alias_text(g.title) = 'old school runescape'
  limit 1
),
inserted_osrs as (
  insert into public.games (id, title, genre)
  select
    'f5e420d7-22f9-4ac7-a4d7-16d58bc8f3d2'::uuid,
    'Old School RuneScape',
    'MMORPG'
  where not exists (select 1 from existing_osrs)
  returning id
),
target_osrs as (
  select id from inserted_osrs
  union all
  select id from existing_osrs
)
insert into public.game_badge_aliases (
  game_id,
  alias,
  is_ambiguous,
  confidence_score,
  priority,
  created_by,
  notes
)
select
  target_osrs.id,
  seed.alias,
  seed.is_ambiguous,
  seed.confidence_score,
  seed.priority,
  '20260226180000',
  seed.notes
from target_osrs
cross join (
  values
    ('OSRS', false, 0.95::double precision, 10, 'Canonical community acronym'),
    ('Old School RuneScape', false, 0.97::double precision, 5, 'Canonical title'),
    ('Old School Runescape', false, 0.94::double precision, 12, 'Common capitalization variant'),
    ('OSRS game', false, 0.97::double precision, 4, 'Phrase variant with game context'),
    ('RuneScape', true, 0.70::double precision, 200, 'Ambiguous with RuneScape 3')
) as seed(alias, is_ambiguous, confidence_score, priority, notes)
on conflict (game_id, alias) do update
set
  is_ambiguous = excluded.is_ambiguous,
  is_active = true,
  confidence_score = excluded.confidence_score,
  priority = excluded.priority,
  created_by = excluded.created_by,
  notes = excluded.notes;

-- Seed aliases for existing games (safe title aliases + curated phrase aliases).
insert into public.game_badge_aliases (
  game_id,
  alias,
  is_ambiguous,
  confidence_score,
  priority,
  created_by,
  notes
)
select
  g.id,
  g.title,
  case when lower(trim(g.title)) in ('marathon') then true else false end,
  case when lower(trim(g.title)) in ('marathon') then 0.76 else 0.90 end,
  case when lower(trim(g.title)) in ('marathon') then 150 else 60 end,
  '20260226180000',
  'Auto-seeded canonical title alias'
from public.games g
where trim(coalesce(g.title, '')) <> ''
on conflict (game_id, alias) do nothing;

insert into public.game_badge_aliases (
  game_id,
  alias,
  is_ambiguous,
  confidence_score,
  priority,
  created_by,
  notes
)
select
  g.id,
  g.title || ' game',
  false,
  0.94,
  20,
  '20260226180000',
  'Auto-seeded phrase alias'
from public.games g
where trim(coalesce(g.title, '')) <> ''
on conflict (game_id, alias) do nothing;

insert into public.game_badge_aliases (
  game_id,
  alias,
  is_ambiguous,
  confidence_score,
  priority,
  created_by,
  notes
)
select
  g.id,
  seed.alias,
  seed.is_ambiguous,
  seed.confidence_score,
  seed.priority,
  '20260226180000',
  seed.notes
from public.games g
join (
  values
    ('marathon', 'Bungie Marathon', false, 0.96::double precision, 5, 'Disambiguated franchise phrase'),
    ('marathon', 'Marathon game', false, 0.95::double precision, 8, 'Disambiguated with game context'),
    ('marathon', 'Marathon alpha', false, 0.92::double precision, 12, 'Likely game-specific phrase'),
    ('pragmata', 'Pragmata', false, 0.96::double precision, 6, 'Canonical safe title')
) as seed(game_title, alias, is_ambiguous, confidence_score, priority, notes)
  on lower(g.title) = seed.game_title
on conflict (game_id, alias) do update
set
  is_ambiguous = excluded.is_ambiguous,
  is_active = true,
  confidence_score = excluded.confidence_score,
  priority = excluded.priority,
  created_by = excluded.created_by,
  notes = excluded.notes;

create or replace function public.resolve_post_game_badge_alias_v1(
  p_title text,
  p_body text
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
  padded_text text;
  has_game_context_terms boolean;
begin
  normalized_text := public.normalize_game_badge_alias_text(coalesce(p_title, '') || ' ' || coalesce(p_body, ''));

  if normalized_text = '' then
    return;
  end if;

  padded_text := ' ' || normalized_text || ' ';
  has_game_context_terms :=
    position(' game ' in padded_text) > 0
    or position(' gaming ' in padded_text) > 0
    or position(' patch ' in padded_text) > 0
    or position(' gameplay ' in padded_text) > 0
    or position(' trailer ' in padded_text) > 0
    or position(' alpha ' in padded_text) > 0
    or position(' beta ' in padded_text) > 0
    or position(' raid ' in padded_text) > 0
    or position(' quest ' in padded_text) > 0
    or position(' boss ' in padded_text) > 0;

  return query
  with candidates as (
    select
      gba.game_id,
      gba.alias,
      gba.normalized_alias,
      gba.is_ambiguous,
      gba.confidence_score,
      gba.priority
    from public.game_badge_aliases gba
    where gba.is_active
      and gba.normalized_alias <> ''
      and position(' ' || gba.normalized_alias || ' ' in padded_text) > 0
  ),
  filtered as (
    select *
    from candidates
    where not is_ambiguous or has_game_context_terms
  ),
  ranked as (
    select
      f.*,
      count(*) over () as candidate_count,
      row_number() over (
        order by
          case when f.is_ambiguous then 1 else 0 end asc,
          f.priority asc,
          char_length(f.normalized_alias) desc,
          f.confidence_score desc,
          f.alias asc
      ) as rn
    from filtered f
  ),
  chosen as (
    select
      r.game_id,
      case
        when r.is_ambiguous then least(r.confidence_score, 0.72)
        when r.candidate_count > 1 then least(r.confidence_score, 0.84)
        else r.confidence_score
      end as effective_score
    from ranked r
    where r.rn = 1
  )
  select
    'game:' || lower(c.game_id::text) as primary_badge_key,
    'text_rules' as badge_assignment_source,
    case when c.effective_score >= 0.85 then 'high' else 'medium' end as badge_confidence_tier,
    c.effective_score as badge_confidence_score
  from chosen c;
end;
$$;

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
  alias_primary_badge_key text;
  alias_source text;
  alias_confidence_tier text;
  alias_confidence_score double precision;
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

  select
    alias_match.primary_badge_key,
    alias_match.badge_assignment_source,
    alias_match.badge_confidence_tier,
    alias_match.badge_confidence_score
  into
    alias_primary_badge_key,
    alias_source,
    alias_confidence_tier,
    alias_confidence_score
  from public.resolve_post_game_badge_alias_v1(p_title, p_body) alias_match
  limit 1;

  if alias_primary_badge_key is not null then
    return query
    select
      alias_primary_badge_key,
      coalesce(alias_source, 'text_rules'),
      coalesce(alias_confidence_tier, 'medium'),
      coalesce(alias_confidence_score, 0.80::double precision);
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
  badge_assignment_source = d.badge_assignment_source,
  badge_confidence_tier = d.badge_confidence_tier,
  badge_confidence_score = d.badge_confidence_score,
  badge_assignment_status = coalesce(nullif(btrim(p.badge_assignment_status), ''), 'assigned'),
  badge_assigned_at = coalesce(p.badge_assigned_at, now())
from derived d
where p.id = d.id
  and (
    p.primary_badge_key is null
    or btrim(p.primary_badge_key) = ''
    or p.primary_badge_key in ('general_gaming', 'unspecified', 'creator', 'industry', 'platform', 'event', 'multi_game')
    or (
      coalesce(nullif(btrim(p.badge_assignment_source), ''), 'text_rules') in ('text_rules', 'async_enrichment')
      and p.primary_badge_key not like 'game:%'
    )
  );

commit;
