-- Remove redundant legacy policy on public.users.
-- "users_rw_own" already covers authenticated INSERT/UPDATE for own row.

drop policy if exists "Users can insert own profile" on public.users;
