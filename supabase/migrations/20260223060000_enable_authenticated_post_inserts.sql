-- Enable authenticated users to create posts.
-- Keep INSERT policy explicit to authenticated users.

grant insert on table public.posts to authenticated;

drop policy if exists "Users can insert posts" on public.posts;

create policy "Users can insert posts"
on public.posts
for insert
to authenticated
with check (auth.uid() = author_id);
