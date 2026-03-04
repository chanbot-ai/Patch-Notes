-- User favorite games: first 3 game selections become profile badges
-- These appear as small icons next to usernames (like team badges in Sleeper)

begin;

-- ── Table ─────────────────────────────────────────────────────────────

create table if not exists public.user_favorite_games (
    user_id uuid not null references public.users(id) on delete cascade,
    game_id uuid not null references public.games(id) on delete cascade,
    ordinal int not null check (ordinal between 1 and 3),
    created_at timestamp default now(),
    primary key (user_id, ordinal),
    unique (user_id, game_id)
);

alter table public.user_favorite_games enable row level security;

create policy "Anyone can read favorite games"
    on public.user_favorite_games for select
    using (true);

create policy "Users can manage their own favorite games"
    on public.user_favorite_games for all
    using (auth.uid() = user_id)
    with check (auth.uid() = user_id);

-- ── Set favorite games RPC ────────────────────────────────────────────

create or replace function public.set_user_favorite_games(
    p_user_id uuid,
    p_game_ids uuid[]
)
returns void
language plpgsql
security definer
as $$
declare
    i int;
    max_idx int;
begin
    delete from public.user_favorite_games where user_id = p_user_id;

    max_idx := least(coalesce(array_length(p_game_ids, 1), 0), 3);

    for i in 1..max_idx loop
        insert into public.user_favorite_games (user_id, game_id, ordinal)
        values (p_user_id, p_game_ids[i], i);
    end loop;
end;
$$;

grant execute on function public.set_user_favorite_games(uuid, uuid[]) to authenticated;

-- ── Fetch favorite games for multiple users ───────────────────────────

create or replace function public.fetch_user_favorite_games(
    p_user_ids uuid[]
)
returns table (
    user_id uuid,
    game_id uuid,
    ordinal int,
    game_title text,
    cover_image_url text
)
language sql stable
as $$
    select ufg.user_id, ufg.game_id, ufg.ordinal, g.title, g.cover_image_url
    from public.user_favorite_games ufg
    join public.games g on g.id = ufg.game_id
    where ufg.user_id = any(p_user_ids)
    order by ufg.user_id, ufg.ordinal;
$$;

grant execute on function public.fetch_user_favorite_games(uuid[]) to anon;
grant execute on function public.fetch_user_favorite_games(uuid[]) to authenticated;

commit;
