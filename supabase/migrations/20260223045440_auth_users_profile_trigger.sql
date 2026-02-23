-- Auto-create public.users rows from auth.users signups.
-- Uses a deterministic placeholder username to satisfy NOT NULL UNIQUE.

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  generated_username text;
begin
  generated_username := 'user_' || replace(new.id::text, '-', '');

  insert into public.users (
    id,
    email,
    username,
    onboarding_complete
  )
  values (
    new.id,
    new.email,
    generated_username,
    false
  )
  on conflict (id) do update
  set email = excluded.email;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;

create trigger on_auth_user_created
after insert on auth.users
for each row
execute function public.handle_new_user();

-- Backfill any auth users that do not yet have a public.users row.
insert into public.users (
  id,
  email,
  username,
  onboarding_complete
)
select
  au.id,
  au.email,
  'user_' || replace(au.id::text, '-', '') as username,
  false as onboarding_complete
from auth.users au
left join public.users pu
  on pu.id = au.id
where pu.id is null
on conflict (id) do update
set email = excluded.email;
