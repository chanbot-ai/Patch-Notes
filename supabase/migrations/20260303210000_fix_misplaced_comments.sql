-- Fix misplaced comments: GTA VI comments were on Elden Ring post,
-- Nightreign comments were on Doom post.

begin;

-- Move GTA VI comments from Elden Ring post (b0000001-...-01) to GTA VI post (b0000001-...-05)
update public.comments
set post_id = 'b0000001-0000-0000-0000-000000000005'
where id in (
  'd0000001-0000-0000-0000-00000000000b',
  'd0000001-0000-0000-0000-00000000000c',
  'd0000001-0000-0000-0000-00000000000d'
);

-- Move Nightreign comments from Doom post (b0000001-...-10) to Nightreign post (c0000001-...-08)
update public.comments
set post_id = 'c0000001-0000-0000-0000-000000000008'
where id in (
  'd0000001-0000-0000-0000-000000000005',
  'd0000001-0000-0000-0000-000000000006',
  'd0000001-0000-0000-0000-000000000007'
);

-- Add proper Elden Ring themed comments on the Elden Ring post
insert into public.comments (id, post_id, user_id, body, parent_comment_id, created_at)
values
  ('d0000001-0000-0000-0000-000000000020', 'b0000001-0000-0000-0000-000000000001', '9389df2a-0f12-46d7-ab57-25f237c3fd2a',
   'Messmer is probably the best boss FromSoft has ever made. That second phase transition is pure cinema.', null, now() - interval '6 hours'),
  ('d0000001-0000-0000-0000-000000000021', 'b0000001-0000-0000-0000-000000000001', 'da2955ad-a0ca-4955-9d8c-f1ce25f798a2',
   'The Scadutree fragments are genius. Forces you to actually explore instead of just rushing bosses.', null, now() - interval '5 hours'),
  ('d0000001-0000-0000-0000-000000000022', 'b0000001-0000-0000-0000-000000000001', '6419e893-d23d-42c6-ab12-48ae110de9bf',
   'Agreed! The hidden areas in this DLC are some of FromSoft''s best level design work ever.', 'd0000001-0000-0000-0000-000000000021', now() - interval '4 hours')
on conflict (id) do nothing;

-- Add Doom themed comments on the Doom post
insert into public.comments (id, post_id, user_id, body, parent_comment_id, created_at)
values
  ('d0000001-0000-0000-0000-000000000023', 'b0000001-0000-0000-0000-000000000010', '9389df2a-0f12-46d7-ab57-25f237c3fd2a',
   '92 on Metacritic is absolutely deserved. The dragon mount alone is worth it.', null, now() - interval '5 hours'),
  ('d0000001-0000-0000-0000-000000000024', 'b0000001-0000-0000-0000-000000000010', 'da2955ad-a0ca-4955-9d8c-f1ce25f798a2',
   'The shield combat is a total game changer. id Software keeps innovating.', null, now() - interval '4 hours'),
  ('d0000001-0000-0000-0000-000000000025', 'b0000001-0000-0000-0000-000000000010', '6419e893-d23d-42c6-ab12-48ae110de9bf',
   'Medieval setting was the perfect move. Best DOOM since 2016 easily.', 'd0000001-0000-0000-0000-000000000024', now() - interval '3 hours')
on conflict (id) do nothing;

-- Update comment_count on affected posts
update public.post_metrics set comment_count = (
  select count(*) from public.comments where comments.post_id = post_metrics.post_id
)
where post_id in (
  'b0000001-0000-0000-0000-000000000001',
  'b0000001-0000-0000-0000-000000000005',
  'b0000001-0000-0000-0000-000000000010',
  'c0000001-0000-0000-0000-000000000008'
);

commit;
