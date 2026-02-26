-- Personalized following feed view (backend-authoritative filtering/ranking).

-- Ensure authenticated users can read their own follows for the view path.
drop policy if exists "Users can follow games" on public.user_followed_games;
create policy "Users can follow games"
on public.user_followed_games
for insert
to authenticated
with check (auth.uid() = user_id);

drop policy if exists "Users can view own followed games" on public.user_followed_games;
create policy "Users can view own followed games"
on public.user_followed_games
for select
to authenticated
using (auth.uid() = user_id);

drop policy if exists "Users can unfollow games" on public.user_followed_games;
create policy "Users can unfollow games"
on public.user_followed_games
for delete
to authenticated
using (auth.uid() = user_id);

create or replace view public.following_feed_view
with (security_invoker = true) as
select
  p.*,
  pm.reaction_count,
  pm.comment_count,
  pm.hot_score
from public.posts p
join public.post_metrics pm on pm.post_id = p.id
join public.user_followed_games ufg on ufg.game_id = p.game_id
where ufg.user_id = auth.uid()
order by pm.hot_score desc;

revoke all privileges on table public.following_feed_view from anon;
revoke all privileges on table public.following_feed_view from authenticated;
grant select on public.following_feed_view to authenticated;
