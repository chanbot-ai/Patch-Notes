begin;

create or replace function public.game_id_from_primary_badge_key(p_primary_badge_key text)
returns uuid
language sql
immutable
returns null on null input
as $$
  select case
    when lower(trim(p_primary_badge_key)) ~ '^game:[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
      then split_part(lower(trim(p_primary_badge_key)), ':', 2)::uuid
    else null::uuid
  end
$$;

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
  p.badge_assigned_at
from public.posts p
join public.post_metrics pm on pm.post_id = p.id
join public.user_followed_games ufg
  on ufg.game_id = coalesce(p.game_id, public.game_id_from_primary_badge_key(p.primary_badge_key))
left join public.public_profiles pp on pp.id = p.author_id
where ufg.user_id = auth.uid()
order by pm.hot_score desc;

revoke all privileges on table public.following_feed_view from anon;
revoke all privileges on table public.following_feed_view from authenticated;
grant select on table public.following_feed_view to authenticated;

commit;
