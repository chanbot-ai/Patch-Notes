-- Enable reactions on comments while preserving existing post reactions.

-- 1) Add comment target column
alter table public.reactions
add column if not exists comment_id uuid
references public.comments(id)
on delete cascade;

-- 2) Ensure reaction targets are mutually exclusive (post OR comment, never both)
alter table public.reactions
drop constraint if exists reaction_target_check;

alter table public.reactions
add constraint reaction_target_check
check (
  (post_id is not null and comment_id is null)
  or
  (post_id is null and comment_id is not null)
);

-- 3) Indexes for comment-reaction lookups and uniqueness
create index if not exists reactions_comment_id_idx
on public.reactions(comment_id);

create unique index if not exists reactions_comment_id_user_id_reaction_type_id_key
on public.reactions(comment_id, user_id, reaction_type_id)
where comment_id is not null;

-- 4) Tighten/normalize RLS for authenticated reaction writes (insert/delete toggle path)
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
