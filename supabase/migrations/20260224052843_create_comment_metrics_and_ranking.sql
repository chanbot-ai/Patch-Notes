-- Comment metrics/ranking + comment write-path hardening.

-- Align comments table with expected app contract.
alter table public.comments
alter column post_id set not null;

alter table public.comments
alter column user_id set not null;

create index if not exists comments_post_id_created_at_idx
on public.comments(post_id, created_at desc);

-- Tighten comment write policies and add owner-delete support.
drop policy if exists "Users can comment" on public.comments;
create policy "Users can comment"
on public.comments
for insert
to authenticated
with check (auth.uid() = user_id);

drop policy if exists "Users can delete own comments" on public.comments;
create policy "Users can delete own comments"
on public.comments
for delete
to authenticated
using (auth.uid() = user_id);

-- Harden post_metrics comment count maintenance for tightened grants and delete support.
create or replace function public.update_post_metrics_on_comment()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  target_post_id uuid;
begin
  target_post_id := case
    when tg_op = 'DELETE' then old.post_id
    else new.post_id
  end;

  if target_post_id is null then
    if tg_op = 'DELETE' then
      return old;
    end if;
    return new;
  end if;

  update public.post_metrics
  set comment_count = (
    select count(*)::int
    from public.comments
    where post_id = target_post_id
  )
  where post_id = target_post_id;

  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

drop trigger if exists comment_delete_trigger on public.comments;
create trigger comment_delete_trigger
after delete on public.comments
for each row
execute function public.update_post_metrics_on_comment();

-- Metrics table for comment reactions/ranking.
create table if not exists public.comment_metrics (
  comment_id uuid primary key
    references public.comments(id)
    on delete cascade,
  reaction_count integer not null default 0,
  hot_score double precision not null default 0
);

-- Do not expose comment_metrics directly to clients.
revoke all privileges on table public.comment_metrics from anon;
revoke all privileges on table public.comment_metrics from authenticated;

create or replace function public.create_comment_metrics_row()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  insert into public.comment_metrics (comment_id)
  values (new.id)
  on conflict (comment_id) do nothing;
  return new;
end;
$$;

drop trigger if exists comment_insert_metrics_trigger on public.comments;
create trigger comment_insert_metrics_trigger
after insert on public.comments
for each row
execute function public.create_comment_metrics_row();

create or replace function public.update_comment_metrics()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  target_comment_id uuid;
begin
  target_comment_id := case
    when tg_op = 'DELETE' then old.comment_id
    else new.comment_id
  end;

  if target_comment_id is null then
    if tg_op = 'DELETE' then
      return old;
    end if;
    return new;
  end if;

  insert into public.comment_metrics (comment_id)
  values (target_comment_id)
  on conflict (comment_id) do nothing;

  update public.comment_metrics
  set reaction_count = (
      select count(*)::int
      from public.reactions
      where comment_id = target_comment_id
    ),
    hot_score = (
      select count(*)::double precision
      from public.reactions
      where comment_id = target_comment_id
    )
  where comment_id = target_comment_id;

  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

drop trigger if exists reaction_insert_comment_metrics on public.reactions;
drop trigger if exists reaction_delete_comment_metrics on public.reactions;

create trigger reaction_insert_comment_metrics
after insert on public.reactions
for each row
when (new.comment_id is not null)
execute function public.update_comment_metrics();

create trigger reaction_delete_comment_metrics
after delete on public.reactions
for each row
when (old.comment_id is not null)
execute function public.update_comment_metrics();

-- Backfill metrics rows/counts for existing comments.
insert into public.comment_metrics (comment_id)
select c.id
from public.comments c
on conflict (comment_id) do nothing;

update public.comment_metrics cm
set reaction_count = coalesce(r.cnt, 0),
    hot_score = coalesce(r.cnt::double precision, 0)
from (
  select comment_id, count(*)::int as cnt
  from public.reactions
  where comment_id is not null
  group by comment_id
) r
where cm.comment_id = r.comment_id;

create or replace view public.post_comments_ranked as
select
  c.*,
  cm.reaction_count,
  cm.hot_score
from public.comments c
left join public.comment_metrics cm on cm.comment_id = c.id
order by cm.hot_score desc nulls last, c.created_at desc;

revoke all privileges on table public.post_comments_ranked from anon;
revoke all privileges on table public.post_comments_ranked from authenticated;
grant select on public.post_comments_ranked to anon, authenticated;
