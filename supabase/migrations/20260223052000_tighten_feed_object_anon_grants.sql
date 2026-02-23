-- Tighten anon grants on feed-related objects.
-- Keep SELECT for public-read compatibility; remove broad write/admin-like grants.

revoke all privileges on table public.posts from anon;
grant select on table public.posts to anon;

revoke all privileges on table public.post_metrics from anon;
grant select on table public.post_metrics to anon;

revoke all privileges on table public.hot_feed_view from anon;
grant select on table public.hot_feed_view to anon;
