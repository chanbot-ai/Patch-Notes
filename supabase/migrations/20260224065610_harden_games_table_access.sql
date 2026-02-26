alter table public.games enable row level security;

drop policy if exists "Games are viewable by everyone" on public.games;
create policy "Games are viewable by everyone"
on public.games
for select
to public
using (true);

drop policy if exists "Authenticated users can insert games" on public.games;
create policy "Authenticated users can insert games"
on public.games
for insert
to authenticated
with check (true);

drop policy if exists "Authenticated users can update games" on public.games;
create policy "Authenticated users can update games"
on public.games
for update
to authenticated
using (true)
with check (true);

revoke all privileges on table public.games from anon;
revoke all privileges on table public.games from authenticated;
grant select on table public.games to anon;
grant select, insert, update on table public.games to authenticated;

comment on table public.games is
    'Game catalog rows referenced by posts and follows. Readable by clients; authenticated clients may insert/update catalog entries used by app posting/follow flows.';
