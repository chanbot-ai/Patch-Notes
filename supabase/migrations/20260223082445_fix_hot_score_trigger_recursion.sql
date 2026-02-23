create or replace function public.recalc_hot_score()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  post_created_at timestamp without time zone;
begin
  select p.created_at
  into post_created_at
  from public.posts p
  where p.id = new.post_id;

  new.hot_score :=
    (ln(coalesce(new.reaction_count, 0) + 1) * 0.6)
    + (coalesce(new.velocity_score, 0) * 1.2)
    + exp(
      -extract(epoch from (now() - coalesce(post_created_at, now()))) / 86400
    );

  return new;
end;
$$;

drop trigger if exists hot_score_trigger on public.post_metrics;
create trigger hot_score_trigger
before update on public.post_metrics
for each row
execute function public.recalc_hot_score();

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

  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;
