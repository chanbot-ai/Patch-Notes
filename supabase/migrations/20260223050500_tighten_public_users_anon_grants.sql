-- Tighten anon privileges on public.users.
-- RLS still governs row access, but anon should not have write-like table grants.

revoke all privileges on table public.users from anon;

grant select on table public.users to anon;
