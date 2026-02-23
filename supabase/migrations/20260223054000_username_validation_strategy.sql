-- Backend-enforced username validation strategy.
-- Allows deterministic trigger placeholders pre-onboarding while reserving `user_`
-- for system-generated placeholders and requiring a real username after onboarding.

create or replace function public.is_placeholder_username(candidate text)
returns boolean
language sql
immutable
strict
set search_path = public
as $$
  select candidate ~ '^user_[0-9a-f]{32}$'
$$;

comment on function public.is_placeholder_username(text)
is 'True for deterministic placeholder usernames (user_<uuid without dashes>) assigned by the auth signup trigger.';

create or replace function public.is_valid_app_username(candidate text)
returns boolean
language sql
immutable
strict
set search_path = public
as $$
  select
    char_length(candidate) between 3 and 32
    and candidate ~ '^[a-z0-9_]+$'
    and candidate !~ '^user_'
$$;

comment on function public.is_valid_app_username(text)
is 'True for user-editable usernames: 3-32 chars, lowercase letters/numbers/underscore only, and reserved user_ prefix is disallowed.';

alter table public.users
  drop constraint if exists users_username_allowed_values_check;

alter table public.users
  drop constraint if exists users_onboarding_complete_requires_real_username_check;

alter table public.users
  add constraint users_username_allowed_values_check
  check (
    public.is_placeholder_username(username)
    or public.is_valid_app_username(username)
  ) not valid;

alter table public.users
  add constraint users_onboarding_complete_requires_real_username_check
  check (
    not coalesce(onboarding_complete, false)
    or not public.is_placeholder_username(username)
  ) not valid;

alter table public.users
  validate constraint users_username_allowed_values_check;

alter table public.users
  validate constraint users_onboarding_complete_requires_real_username_check;

comment on column public.users.username
is 'Unique username. Trigger-created signup rows use a deterministic placeholder (user_<uuid without dashes>) until onboarding completes. User-edited usernames must be 3-32 chars, lowercase alphanumeric/underscore, and may not use the reserved user_ prefix.';
