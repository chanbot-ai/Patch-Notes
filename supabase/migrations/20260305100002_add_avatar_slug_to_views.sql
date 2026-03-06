-- ============================================================
-- Add avatar_slug to public_profiles and comment views
-- ============================================================

-- 1. Update public_profiles view to include avatar_slug
CREATE OR REPLACE VIEW public.public_profiles AS
SELECT
  u.id,
  u.username,
  u.display_name,
  u.avatar_url,
  u.created_at,
  u.is_bot,
  u.avatar_slug
FROM public.users u
WHERE u.onboarding_complete = true
  AND (u.is_bot = true OR NOT public.is_placeholder_username(u.username));

-- 2. Drop and recreate post_comments_ranked (column set changed due to reply_to_comment_id)
DROP VIEW IF EXISTS public.post_comments_ranked;
CREATE VIEW public.post_comments_ranked AS
SELECT
  c.*,
  cm.reaction_count,
  cm.hot_score,
  pp.username AS author_username,
  pp.display_name AS author_display_name,
  pp.avatar_url AS author_avatar_url,
  pp.created_at AS author_created_at,
  pp.avatar_slug AS author_avatar_slug
FROM public.comments c
LEFT JOIN public.comment_metrics cm ON cm.comment_id = c.id
LEFT JOIN public.public_profiles pp ON pp.id = c.user_id
ORDER BY cm.hot_score DESC NULLS LAST, c.created_at DESC;

REVOKE ALL PRIVILEGES ON TABLE public.post_comments_ranked FROM anon;
REVOKE ALL PRIVILEGES ON TABLE public.post_comments_ranked FROM authenticated;
GRANT SELECT ON TABLE public.post_comments_ranked TO anon;
GRANT SELECT ON TABLE public.post_comments_ranked TO authenticated;

-- 3. Drop and recreate post_comments_recent
DROP VIEW IF EXISTS public.post_comments_recent;
CREATE VIEW public.post_comments_recent AS
SELECT
  c.*,
  cm.reaction_count,
  cm.hot_score,
  pp.username AS author_username,
  pp.display_name AS author_display_name,
  pp.avatar_url AS author_avatar_url,
  pp.created_at AS author_created_at,
  pp.avatar_slug AS author_avatar_slug
FROM public.comments c
LEFT JOIN public.comment_metrics cm ON cm.comment_id = c.id
LEFT JOIN public.public_profiles pp ON pp.id = c.user_id
ORDER BY c.created_at DESC;

REVOKE ALL PRIVILEGES ON TABLE public.post_comments_recent FROM anon;
REVOKE ALL PRIVILEGES ON TABLE public.post_comments_recent FROM authenticated;
GRANT SELECT ON TABLE public.post_comments_recent TO anon;
GRANT SELECT ON TABLE public.post_comments_recent TO authenticated;
