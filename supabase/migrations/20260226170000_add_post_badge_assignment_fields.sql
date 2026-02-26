begin;

alter table public.posts
  add column if not exists primary_badge_key text,
  add column if not exists secondary_badge_key text,
  add column if not exists badge_confidence_tier text,
  add column if not exists badge_confidence_score double precision,
  add column if not exists badge_assignment_source text,
  add column if not exists badge_assignment_status text,
  add column if not exists badge_assigned_at timestamp without time zone;

create or replace function public.apply_default_post_badge_assignment()
returns trigger
language plpgsql
as $$
begin
  if new.primary_badge_key is null or btrim(new.primary_badge_key) = '' then
    if new.game_id is not null then
      new.primary_badge_key := 'game:' || lower(new.game_id::text);
      new.badge_assignment_source := coalesce(nullif(btrim(new.badge_assignment_source), ''), 'attachment');
      new.badge_confidence_tier := coalesce(nullif(btrim(new.badge_confidence_tier), ''), 'high');
      new.badge_confidence_score := coalesce(new.badge_confidence_score, 0.95);
    else
      new.primary_badge_key := 'general_gaming';
      new.badge_assignment_source := coalesce(nullif(btrim(new.badge_assignment_source), ''), 'text_rules');
      new.badge_confidence_tier := coalesce(nullif(btrim(new.badge_confidence_tier), ''), 'low');
      new.badge_confidence_score := coalesce(new.badge_confidence_score, 0.45);
    end if;
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

drop trigger if exists post_badge_assignment_defaults_trigger on public.posts;
create trigger post_badge_assignment_defaults_trigger
before insert on public.posts
for each row
execute function public.apply_default_post_badge_assignment();

update public.posts p
set
  primary_badge_key = coalesce(
    nullif(btrim(p.primary_badge_key), ''),
    case
      when p.game_id is not null then 'game:' || lower(p.game_id::text)
      else 'general_gaming'
    end
  ),
  badge_assignment_source = coalesce(
    nullif(btrim(p.badge_assignment_source), ''),
    case
      when p.game_id is not null then 'attachment'
      else 'text_rules'
    end
  ),
  badge_confidence_tier = coalesce(
    nullif(btrim(p.badge_confidence_tier), ''),
    case
      when p.game_id is not null then 'high'
      else 'low'
    end
  ),
  badge_confidence_score = coalesce(
    p.badge_confidence_score,
    case
      when p.game_id is not null then 0.95
      else 0.45
    end
  ),
  badge_assignment_status = coalesce(nullif(btrim(p.badge_assignment_status), ''), 'assigned'),
  badge_assigned_at = coalesce(p.badge_assigned_at, p.created_at, now())
where
  p.primary_badge_key is null
  or btrim(p.primary_badge_key) = ''
  or p.badge_assignment_source is null
  or btrim(p.badge_assignment_source) = ''
  or p.badge_confidence_tier is null
  or btrim(p.badge_confidence_tier) = ''
  or p.badge_confidence_score is null
  or p.badge_assignment_status is null
  or btrim(p.badge_assignment_status) = ''
  or p.badge_assigned_at is null;

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
  p.badge_assigned_at
from public.posts p
join public.post_metrics m on m.post_id = p.id
left join public.public_profiles pp on pp.id = p.author_id
order by m.hot_score desc;

revoke all privileges on table public.hot_feed_view from anon;
revoke all privileges on table public.hot_feed_view from authenticated;
grant select on table public.hot_feed_view to anon;
grant select on table public.hot_feed_view to authenticated;

commit;
