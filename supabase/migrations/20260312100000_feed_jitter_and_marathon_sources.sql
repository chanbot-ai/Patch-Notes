-- Feed ordering jitter: prevent batch-inserted posts from clustering
-- Marathon game sources: ensure Marathon posts appear under game pill

-- 1. Update post_metrics trigger to include initial hot_score with jitter
create or replace function create_post_metrics_row()
returns trigger
language plpgsql
security definer
as $$
begin
  insert into public.post_metrics (post_id, hot_score)
  values (
    new.id,
    -- Initial score: time decay (starts near 1.0) + random jitter to prevent clustering
    exp(-extract(epoch from (now() - new.created_at)) / 259200) + (random() * 0.05)
  );
  return new;
end;
$$;

-- 2. Backfill jitter for existing zero-engagement posts
update post_metrics pm
set hot_score = exp(
  -extract(epoch from (now() - p.created_at)) / 259200
) + (random() * 0.05)
from posts p
where pm.post_id = p.id
and pm.hot_score = 0
and pm.reaction_count = 0
and pm.comment_count = 0;

-- 3. Add Marathon-specific bot sources
insert into bot_content_sources (bot_user_id, source_type, source_identifier, game_id, is_active)
values
  ('b0100000-0000-0000-0000-000000000001', 'reddit', 'MarathonTheGame', 'a5000001-0000-0000-0000-000000000002', true),
  ('b0100000-0000-0000-0000-000000000001', 'reddit', 'Marathon', 'a5000001-0000-0000-0000-000000000002', true)
on conflict do nothing;

-- 4. Fix existing Marathon posts with NULL game_id
update posts set game_id = 'a5000001-0000-0000-0000-000000000002'
where game_id is null
and lower(title) like '%marathon%'
and lower(title) not like '%call of duty%'
and lower(title) not like '%warzone%';
