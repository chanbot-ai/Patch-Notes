-- Improve hot score ranking formula:
--   1. Add comment_count to hot_score (weighted 0.8, higher than reactions at 0.6)
--   2. Soften time decay from 1-day to 3-day half-life
--   3. Fix velocity_score to decay over time (12-hour half-life) instead of accumulating
--   4. Comments bump velocity at 1.5x the weight of reactions
--   5. Backfill all existing post scores

begin;

-- ── 1. Rewrite hot score trigger function ────────────────────────────────

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
    + (ln(coalesce(new.comment_count, 0) + 1) * 0.8)
    + (coalesce(new.velocity_score, 0) * 1.2)
    + exp(
      -extract(epoch from (now() - coalesce(post_created_at, now()))) / 259200
    );

  return new;
end;
$$;

-- Trigger already exists as BEFORE UPDATE on post_metrics; no need to recreate.

-- ── 2. Rewrite reaction handler with velocity decay ──────────────────────

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
  current_velocity double precision;
  current_last_reaction_at timestamp without time zone;
  decayed_velocity double precision;
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
    when tg_op = 'INSERT' then 1.0
    when tg_op = 'DELETE' then -1.0
    else 0.0
  end;

  -- Read current velocity and last_reaction_at for decay calculation
  select pm.velocity_score, pm.last_reaction_at
  into current_velocity, current_last_reaction_at
  from public.post_metrics pm
  where pm.post_id = target_post_id;

  -- Decay existing velocity based on time since last reaction (12-hour half-life)
  decayed_velocity := coalesce(current_velocity, 0)
    * exp(
      -extract(epoch from (now() - coalesce(current_last_reaction_at, now()))) / 43200
    );

  update public.post_metrics
  set
    reaction_count = reaction_total,
    last_reaction_at = latest_reaction_at,
    velocity_score = greatest(decayed_velocity + velocity_delta, 0)
  where post_id = target_post_id;

  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

-- ── 3. Rewrite comment handler to also bump velocity ─────────────────────

create or replace function public.update_post_metrics_on_comment()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  target_post_id uuid;
  comment_total integer;
  comment_velocity_delta double precision;
  current_velocity double precision;
  current_last_reaction_at timestamp without time zone;
  decayed_velocity double precision;
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

  select count(*)::int
  into comment_total
  from public.comments
  where post_id = target_post_id;

  -- Comments are worth 1.5x a reaction in velocity
  comment_velocity_delta := case
    when tg_op = 'INSERT' then 1.5
    when tg_op = 'DELETE' then -1.5
    else 0.0
  end;

  -- Read current velocity for decay calculation
  select pm.velocity_score, pm.last_reaction_at
  into current_velocity, current_last_reaction_at
  from public.post_metrics pm
  where pm.post_id = target_post_id;

  -- Decay existing velocity (12-hour half-life)
  decayed_velocity := coalesce(current_velocity, 0)
    * exp(
      -extract(epoch from (now() - coalesce(current_last_reaction_at, now()))) / 43200
    );

  update public.post_metrics
  set
    comment_count = comment_total,
    velocity_score = greatest(decayed_velocity + comment_velocity_delta, 0)
  where post_id = target_post_id;

  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

-- ── 4. Backfill all existing post scores with the new formula ────────────

-- A no-op velocity_score write triggers the BEFORE UPDATE hot_score_trigger,
-- which recalculates hot_score using the new formula for every row.
update public.post_metrics
set velocity_score = coalesce(velocity_score, 0);

commit;
