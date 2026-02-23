begin;

create or replace view public.public_profiles as
select
  u.id,
  u.username,
  u.display_name,
  u.avatar_url,
  u.created_at
from public.users u
where u.onboarding_complete = true
  and not public.is_placeholder_username(u.username);

comment on view public.public_profiles is
  'Public-safe profile surface for app reads. Excludes private columns such as email and only includes completed profiles.';

revoke all on table public.public_profiles from public;
revoke all on table public.public_profiles from anon;
revoke all on table public.public_profiles from authenticated;

grant select on table public.public_profiles to anon;
grant select on table public.public_profiles to authenticated;

commit;
