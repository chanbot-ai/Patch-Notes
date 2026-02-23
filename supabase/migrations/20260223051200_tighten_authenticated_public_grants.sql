-- Tighten authenticated grants to match current app behavior.
-- App currently writes public.users and reads the feed via hot_feed_view.
-- Keep read access on posts/post_metrics for feed compatibility and debugging.

revoke all privileges on table public.users from authenticated;
grant select, insert, update on table public.users to authenticated;

revoke all privileges on table public.posts from authenticated;
grant select on table public.posts to authenticated;

revoke all privileges on table public.post_metrics from authenticated;
grant select on table public.post_metrics to authenticated;

revoke all privileges on table public.hot_feed_view from authenticated;
grant select on table public.hot_feed_view to authenticated;
