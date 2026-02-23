create or replace function public.update_post_metrics_on_reaction()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  target_post_id uuid;
  reaction_total integer;
  latest_reaction_at timestamp without time zone;
  velocity_delta double precision;
begin
  target_post_id := coalesce(new.post_id, old.post_id);

  if target_post_id is null then
    return coalesce(new, old);
  end if;

  select
    count(*)::int,
    max(created_at)
  into
    reaction_total,
    latest_reaction_at
  from public.reactions
  where post_id = target_post_id;

  velocity_delta := case
    when tg_op = 'INSERT' then 1
    when tg_op = 'DELETE' then -1
    else 0
  end;

  update public.post_metrics
  set
    reaction_count = reaction_total,
    last_reaction_at = latest_reaction_at,
    velocity_score = greatest(coalesce(velocity_score, 0) + velocity_delta, 0)
  where post_id = target_post_id;

  return coalesce(new, old);
end;
$$;

drop trigger if exists reaction_insert_trigger on public.reactions;
create trigger reaction_insert_trigger
after insert on public.reactions
for each row
execute function public.update_post_metrics_on_reaction();

drop trigger if exists reaction_delete_trigger on public.reactions;
create trigger reaction_delete_trigger
after delete on public.reactions
for each row
execute function public.update_post_metrics_on_reaction();

create or replace view public.post_reaction_counts as
select
  r.post_id,
  r.reaction_type_id,
  count(*)::int as count
from public.reactions r
group by r.post_id, r.reaction_type_id;

grant select on table public.post_reaction_counts to anon;
grant select on table public.post_reaction_counts to authenticated;

drop policy if exists "Users can react" on public.reactions;
create policy "Users can react"
on public.reactions
for insert
to authenticated
with check (auth.uid() = user_id);

drop policy if exists "Users can unreact" on public.reactions;
create policy "Users can unreact"
on public.reactions
for delete
to authenticated
using (auth.uid() = user_id);

revoke all privileges on table public.reaction_types from anon;
grant select on table public.reaction_types to anon;

revoke all privileges on table public.reaction_types from authenticated;
grant select on table public.reaction_types to authenticated;

revoke all privileges on table public.reactions from anon;
grant select on table public.reactions to anon;

revoke all privileges on table public.reactions from authenticated;
grant select, insert, delete on table public.reactions to authenticated;
