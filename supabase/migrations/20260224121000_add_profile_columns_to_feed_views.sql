begin;

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
  pp.created_at as author_created_at
from public.posts p
join public.post_metrics m on m.post_id = p.id
left join public.public_profiles pp on pp.id = p.author_id
order by m.hot_score desc;

create or replace view public.following_feed_view
with (security_invoker = true) as
select
  p.*,
  pm.reaction_count,
  pm.comment_count,
  pm.hot_score,
  pp.username as author_username,
  pp.display_name as author_display_name,
  pp.avatar_url as author_avatar_url,
  pp.created_at as author_created_at
from public.posts p
join public.post_metrics pm on pm.post_id = p.id
join public.user_followed_games ufg on ufg.game_id = p.game_id
left join public.public_profiles pp on pp.id = p.author_id
where ufg.user_id = auth.uid()
order by pm.hot_score desc;

create or replace view public.post_comments_ranked as
select
  c.*,
  cm.reaction_count,
  cm.hot_score,
  pp.username as author_username,
  pp.display_name as author_display_name,
  pp.avatar_url as author_avatar_url,
  pp.created_at as author_created_at
from public.comments c
left join public.comment_metrics cm on cm.comment_id = c.id
left join public.public_profiles pp on pp.id = c.user_id
order by cm.hot_score desc nulls last, c.created_at desc;

create or replace view public.post_comments_recent as
select
  c.*,
  cm.reaction_count,
  cm.hot_score,
  pp.username as author_username,
  pp.display_name as author_display_name,
  pp.avatar_url as author_avatar_url,
  pp.created_at as author_created_at
from public.comments c
left join public.comment_metrics cm on cm.comment_id = c.id
left join public.public_profiles pp on pp.id = c.user_id;

revoke all privileges on table public.hot_feed_view from anon;
revoke all privileges on table public.hot_feed_view from authenticated;
grant select on table public.hot_feed_view to anon;
grant select on table public.hot_feed_view to authenticated;

revoke all privileges on table public.following_feed_view from anon;
revoke all privileges on table public.following_feed_view from authenticated;
grant select on table public.following_feed_view to authenticated;

revoke all privileges on table public.post_comments_ranked from anon;
revoke all privileges on table public.post_comments_ranked from authenticated;
grant select on table public.post_comments_ranked to anon;
grant select on table public.post_comments_ranked to authenticated;

revoke all privileges on table public.post_comments_recent from anon;
revoke all privileges on table public.post_comments_recent from authenticated;
grant select on table public.post_comments_recent to anon;
grant select on table public.post_comments_recent to authenticated;

commit;
