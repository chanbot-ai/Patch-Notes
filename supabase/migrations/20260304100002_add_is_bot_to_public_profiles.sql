-- Add is_bot to public_profiles view
CREATE OR REPLACE VIEW public.public_profiles AS
SELECT
  u.id,
  u.username,
  u.display_name,
  u.avatar_url,
  u.created_at,
  u.is_bot
FROM public.users u
WHERE u.onboarding_complete = true
  AND (u.is_bot = true OR NOT public.is_placeholder_username(u.username));
