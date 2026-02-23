-- Make placeholder username behavior explicit and reusable.
-- New auth signups receive a deterministic placeholder username until onboarding updates it.

create or replace function public.generate_placeholder_username(user_id uuid)
returns text
language sql
immutable
strict
set search_path = public
as $$
  select 'user_' || replace(user_id::text, '-', '')
$$;

comment on function public.generate_placeholder_username(uuid)
is 'Generates deterministic placeholder usernames (user_<uuid without dashes>) for auth-trigger-created public.users rows.';

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.users (
    id,
    email,
    username,
    onboarding_complete
  )
  values (
    new.id,
    new.email,
    public.generate_placeholder_username(new.id),
    false
  )
  on conflict (id) do update
  set email = excluded.email;

  return new;
end;
$$;

comment on function public.handle_new_user()
is 'Creates/updates a public.users row for each auth.users signup, assigning a deterministic placeholder username until onboarding completion.';

comment on column public.users.username
is 'Unique username. Signups receive a deterministic placeholder (user_<uuid without dashes>) via public.handle_new_user() until onboarding/profile completion updates it.';
