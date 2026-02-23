-- Lock down public.users so emails are not publicly readable.
-- Authenticated users already have users_rw_own for their own row.
-- Add a SECURITY DEFINER RPC for username availability checks so the app
-- doesn't need broad SELECT access to public.users.

drop policy if exists "Users are viewable by everyone" on public.users;

create or replace function public.is_username_available(
  candidate text,
  requester_user_id uuid default auth.uid()
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select case
    when candidate is null or btrim(candidate) = '' then false
    else not exists (
      select 1
      from public.users u
      where u.username = candidate
        and (requester_user_id is null or u.id <> requester_user_id)
    )
  end
$$;

grant execute on function public.is_username_available(text, uuid) to authenticated;

comment on function public.is_username_available(text, uuid)
is 'Checks username availability without exposing public.users rows/columns. Excludes the requester user ID when provided.';
