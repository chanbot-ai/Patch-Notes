revoke all privileges on table public.post_reaction_counts from anon;
grant select on table public.post_reaction_counts to anon;

revoke all privileges on table public.post_reaction_counts from authenticated;
grant select on table public.post_reaction_counts to authenticated;
