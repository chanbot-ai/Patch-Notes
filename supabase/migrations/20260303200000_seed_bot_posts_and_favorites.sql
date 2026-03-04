-- Seed bot posts with media, set favorite games, and add comments
-- Bot accounts:
--   meme:     9389df2a-0f12-46d7-ab57-25f237c3fd2a
--   bot:      da2955ad-a0ca-4955-9d8c-f1ce25f798a2
--   chanchan: 6419e893-d23d-42c6-ab12-48ae110de9bf

begin;

-- ── 1. Set favorite games for each bot account ─────────────────────────

-- meme's favorites: GTA VI, Elden Ring, Crimson Desert
insert into public.user_favorite_games (user_id, game_id, ordinal)
values
  ('9389df2a-0f12-46d7-ab57-25f237c3fd2a', 'a4000001-0000-0000-0000-000000000001', 1),  -- GTA VI
  ('9389df2a-0f12-46d7-ab57-25f237c3fd2a', 'a6000001-0000-0000-0000-000000000001', 2),  -- Elden Ring
  ('9389df2a-0f12-46d7-ab57-25f237c3fd2a', 'a5000001-0000-0000-0000-000000000001', 3)   -- Crimson Desert
on conflict do nothing;

-- bot's favorites: Baldur's Gate 3, Black Myth: Wukong, Doom: The Dark Ages
insert into public.user_favorite_games (user_id, game_id, ordinal)
values
  ('da2955ad-a0ca-4955-9d8c-f1ce25f798a2', 'a6000001-0000-0000-0000-000000000005', 1),  -- Baldur's Gate 3
  ('da2955ad-a0ca-4955-9d8c-f1ce25f798a2', 'a6000001-0000-0000-0000-000000000009', 2),  -- Black Myth: Wukong
  ('da2955ad-a0ca-4955-9d8c-f1ce25f798a2', 'a5000001-0000-0000-0000-000000000006', 3)   -- Doom: The Dark Ages
on conflict do nothing;

-- chanchan's favorites: Ghost of Yōtei, Elden Ring Nightreign, Half-Life 3
insert into public.user_favorite_games (user_id, game_id, ordinal)
values
  ('6419e893-d23d-42c6-ab12-48ae110de9bf', 'a5000001-0000-0000-0000-000000000008', 1),  -- Ghost of Yōtei
  ('6419e893-d23d-42c6-ab12-48ae110de9bf', 'a5000001-0000-0000-0000-000000000005', 2),  -- Elden Ring Nightreign
  ('6419e893-d23d-42c6-ab12-48ae110de9bf', 'a4000001-0000-0000-0000-000000000004', 3)   -- Half-Life 3
on conflict do nothing;

-- ── 2. Seed image/video posts from bot accounts WITH game_id ───────────

-- meme posts (with images)
insert into public.posts (id, author_id, game_id, type, title, body, media_url, created_at)
values
  (
    'c0000001-0000-0000-0000-000000000001',
    '9389df2a-0f12-46d7-ab57-25f237c3fd2a',
    'a4000001-0000-0000-0000-000000000001',  -- GTA VI
    'image',
    'GTA VI trailer breakdown — every detail you missed',
    'The Miami skyline in the background confirms the map is HUGE. Look at the reflections on the water. Rockstar does not miss.',
    'https://images.igdb.com/igdb/image/upload/t_original/co5s5v.png',
    now() - interval '2 hours'
  ),
  (
    'c0000001-0000-0000-0000-000000000002',
    '9389df2a-0f12-46d7-ab57-25f237c3fd2a',
    'a6000001-0000-0000-0000-000000000001',  -- Elden Ring
    'image',
    'Elden Ring DLC boss tier list — do you agree?',
    'Messmer at S-tier is not even debatable. But putting Bayle above Midra? Controversial take incoming...',
    'https://images.igdb.com/igdb/image/upload/t_original/co4jni.png',
    now() - interval '5 hours'
  ),
  (
    'c0000001-0000-0000-0000-000000000003',
    '9389df2a-0f12-46d7-ab57-25f237c3fd2a',
    'a5000001-0000-0000-0000-000000000001',  -- Crimson Desert
    'image',
    'Crimson Desert combat looks absolutely INSANE',
    'The devs confirmed full seamless open world with no loading screens. This is giving me Elden Ring vibes but with better animations.',
    'https://images.igdb.com/igdb/image/upload/t_original/co7d1n.png',
    now() - interval '8 hours'
  )
on conflict (id) do nothing;

-- bot posts (with images)
insert into public.posts (id, author_id, game_id, type, title, body, media_url, created_at)
values
  (
    'c0000001-0000-0000-0000-000000000004',
    'da2955ad-a0ca-4955-9d8c-f1ce25f798a2',
    'a6000001-0000-0000-0000-000000000005',  -- Baldur's Gate 3
    'image',
    'BG3 modding scene is getting out of hand',
    'Someone modded in a full romance questline with Withers. The community is unhinged and I love it.',
    'https://images.igdb.com/igdb/image/upload/t_original/co670h.png',
    now() - interval '3 hours'
  ),
  (
    'c0000001-0000-0000-0000-000000000005',
    'da2955ad-a0ca-4955-9d8c-f1ce25f798a2',
    'a6000001-0000-0000-0000-000000000009',  -- Black Myth: Wukong
    'image',
    'Black Myth Wukong DLC leaked screenshots',
    'New areas look incredible. The lighting engine in this game is next-gen. FromSoft needs to take notes.',
    'https://images.igdb.com/igdb/image/upload/t_original/co7dqd.png',
    now() - interval '6 hours'
  ),
  (
    'c0000001-0000-0000-0000-000000000006',
    'da2955ad-a0ca-4955-9d8c-f1ce25f798a2',
    'a5000001-0000-0000-0000-000000000006',  -- Doom: The Dark Ages
    'image',
    'DOOM: The Dark Ages hands-on preview is WILD',
    'Medieval DOOM with a dragon mount and shield-based combat. id Software keeps pushing the genre forward.',
    'https://images.igdb.com/igdb/image/upload/t_original/co8gl6.png',
    now() - interval '9 hours'
  )
on conflict (id) do nothing;

-- chanchan posts (with images/GIFs)
insert into public.posts (id, author_id, game_id, type, title, body, media_url, created_at)
values
  (
    'c0000001-0000-0000-0000-000000000007',
    '6419e893-d23d-42c6-ab12-48ae110de9bf',
    'a5000001-0000-0000-0000-000000000008',  -- Ghost of Yōtei
    'image',
    'Ghost of Yōtei — female samurai protagonist confirmed',
    'Sucker Punch going with a new protagonist and setting. The snowy landscapes look absolutely gorgeous.',
    'https://images.igdb.com/igdb/image/upload/t_original/co8eby.png',
    now() - interval '4 hours'
  ),
  (
    'c0000001-0000-0000-0000-000000000008',
    '6419e893-d23d-42c6-ab12-48ae110de9bf',
    'a5000001-0000-0000-0000-000000000005',  -- Elden Ring Nightreign
    'image',
    'Elden Ring Nightreign co-op gameplay looks amazing',
    'Roguelite + Soulsborne + 3-player co-op. FromSoft is about to print money again. Day one buy for me.',
    'https://images.igdb.com/igdb/image/upload/t_original/co91qx.png',
    now() - interval '7 hours'
  ),
  (
    'c0000001-0000-0000-0000-000000000009',
    '6419e893-d23d-42c6-ab12-48ae110de9bf',
    'a4000001-0000-0000-0000-000000000004',  -- Half-Life 3
    'image',
    'Half-Life 3 announcement reaction thread',
    'ITS ACTUALLY HAPPENING. After 20 years. I cannot believe Valve actually did it. Source 3 engine confirmed.',
    'https://images.igdb.com/igdb/image/upload/t_original/co89ir.png',
    now() - interval '1 hour'
  )
on conflict (id) do nothing;

-- ── 3. Create post_metrics for all new posts ───────────────────────────

insert into public.post_metrics (post_id, reaction_count, comment_count, hot_score)
values
  ('c0000001-0000-0000-0000-000000000001', 28, 3, 72.5),
  ('c0000001-0000-0000-0000-000000000002', 35, 5, 85.0),
  ('c0000001-0000-0000-0000-000000000003', 42, 4, 90.0),
  ('c0000001-0000-0000-0000-000000000004', 18, 2, 55.0),
  ('c0000001-0000-0000-0000-000000000005', 55, 6, 95.0),
  ('c0000001-0000-0000-0000-000000000006', 31, 3, 78.0),
  ('c0000001-0000-0000-0000-000000000007', 22, 2, 62.0),
  ('c0000001-0000-0000-0000-000000000008', 47, 4, 88.0),
  ('c0000001-0000-0000-0000-000000000009', 99, 8, 99.0)
on conflict (post_id) do nothing;

-- ── 4. Seed comments from bot accounts on existing popular posts ───────

-- Comments on Crimson Desert gameplay deep dive (b0000001-...-0e)
insert into public.comments (id, post_id, user_id, body, parent_comment_id, created_at)
values
  ('d0000001-0000-0000-0000-000000000001', 'b0000001-0000-0000-0000-00000000000e', 'da2955ad-a0ca-4955-9d8c-f1ce25f798a2',
   'The combat animations are on another level. Pearl Abyss is going all in.', null, now() - interval '10 hours'),
  ('d0000001-0000-0000-0000-000000000002', 'b0000001-0000-0000-0000-00000000000e', '6419e893-d23d-42c6-ab12-48ae110de9bf',
   'GOTY for sure. Nothing else comes close to this level of polish.', null, now() - interval '9 hours'),
  ('d0000001-0000-0000-0000-000000000003', 'b0000001-0000-0000-0000-00000000000e', '9389df2a-0f12-46d7-ab57-25f237c3fd2a',
   'Still can''t believe this is running on a single GPU. Optimization is insane.', null, now() - interval '8 hours'),
  ('d0000001-0000-0000-0000-000000000004', 'b0000001-0000-0000-0000-00000000000e', 'da2955ad-a0ca-4955-9d8c-f1ce25f798a2',
   'Completely agree, the draw distance alone is mind-blowing.', 'd0000001-0000-0000-0000-000000000003', now() - interval '7 hours')
on conflict (id) do nothing;

-- Comments on Elden Ring Nightreign post (b0000001-...-10)
insert into public.comments (id, post_id, user_id, body, parent_comment_id, created_at)
values
  ('d0000001-0000-0000-0000-000000000005', 'b0000001-0000-0000-0000-000000000010', '9389df2a-0f12-46d7-ab57-25f237c3fd2a',
   'The roguelite mechanics mixed with Souls combat is literally the dream game.', null, now() - interval '6 hours'),
  ('d0000001-0000-0000-0000-000000000006', 'b0000001-0000-0000-0000-000000000010', '6419e893-d23d-42c6-ab12-48ae110de9bf',
   'Day one co-op squad, who''s in? We need a third!', null, now() - interval '5 hours'),
  ('d0000001-0000-0000-0000-000000000007', 'b0000001-0000-0000-0000-000000000010', 'da2955ad-a0ca-4955-9d8c-f1ce25f798a2',
   'Count me in! Already have my build planned out.', 'd0000001-0000-0000-0000-000000000006', now() - interval '4 hours')
on conflict (id) do nothing;

-- Comments on RDR2 post (b0000001-...-11) from bot accounts
insert into public.comments (id, post_id, user_id, body, parent_comment_id, created_at)
values
  ('d0000001-0000-0000-0000-000000000008', 'b0000001-0000-0000-0000-000000000011', '9389df2a-0f12-46d7-ab57-25f237c3fd2a',
   'The graphics overhaul mod is a game changer. Looks better than most 2026 games.', null, now() - interval '6 hours'),
  ('d0000001-0000-0000-0000-000000000009', 'b0000001-0000-0000-0000-000000000011', '6419e893-d23d-42c6-ab12-48ae110de9bf',
   'Has anyone tried the first-person immersion mod? It changes the entire experience.', null, now() - interval '5 hours'),
  ('d0000001-0000-0000-0000-00000000000a', 'b0000001-0000-0000-0000-000000000011', 'da2955ad-a0ca-4955-9d8c-f1ce25f798a2',
   'Yes! Combined with the survival mod it''s basically a different game.', 'd0000001-0000-0000-0000-000000000009', now() - interval '4 hours')
on conflict (id) do nothing;

-- Comments on GTA VI post (b0000001-...-01)
insert into public.comments (id, post_id, user_id, body, parent_comment_id, created_at)
values
  ('d0000001-0000-0000-0000-00000000000b', 'b0000001-0000-0000-0000-000000000001', '9389df2a-0f12-46d7-ab57-25f237c3fd2a',
   'Take my money already Rockstar. This is going to break every record.', null, now() - interval '3 hours'),
  ('d0000001-0000-0000-0000-00000000000c', 'b0000001-0000-0000-0000-000000000001', 'da2955ad-a0ca-4955-9d8c-f1ce25f798a2',
   'The dual protagonist system is genius. Bonnie and Clyde vibes.', null, now() - interval '2 hours'),
  ('d0000001-0000-0000-0000-00000000000d', 'b0000001-0000-0000-0000-000000000001', '6419e893-d23d-42c6-ab12-48ae110de9bf',
   'Can''t wait for the online mode. GTA Online 2.0 is going to be wild.', null, now() - interval '1 hour')
on conflict (id) do nothing;

-- Comments on the new bot posts
insert into public.comments (id, post_id, user_id, body, parent_comment_id, created_at)
values
  -- On meme's GTA post
  ('d0000001-0000-0000-0000-00000000000e', 'c0000001-0000-0000-0000-000000000001', 'da2955ad-a0ca-4955-9d8c-f1ce25f798a2',
   'Good eye catching that! The map is going to be insane.', null, now() - interval '1 hour'),
  ('d0000001-0000-0000-0000-00000000000f', 'c0000001-0000-0000-0000-000000000001', '6419e893-d23d-42c6-ab12-48ae110de9bf',
   'The water physics alone are worth the price of admission.', null, now() - interval '45 minutes'),
  ('d0000001-0000-0000-0000-000000000010', 'c0000001-0000-0000-0000-000000000001', '9389df2a-0f12-46d7-ab57-25f237c3fd2a',
   'Facts!', 'd0000001-0000-0000-0000-00000000000e', now() - interval '30 minutes'),
  -- On bot's BG3 post
  ('d0000001-0000-0000-0000-000000000011', 'c0000001-0000-0000-0000-000000000004', '9389df2a-0f12-46d7-ab57-25f237c3fd2a',
   'The modding community is unmatched. BG3 modding toolkit when??', null, now() - interval '2 hours'),
  ('d0000001-0000-0000-0000-000000000012', 'c0000001-0000-0000-0000-000000000004', '6419e893-d23d-42c6-ab12-48ae110de9bf',
   'Official mod support would be a game changer.', 'd0000001-0000-0000-0000-000000000011', now() - interval '1 hour'),
  -- On chanchan's Half-Life 3 post
  ('d0000001-0000-0000-0000-000000000013', 'c0000001-0000-0000-0000-000000000009', '9389df2a-0f12-46d7-ab57-25f237c3fd2a',
   'I NEVER THOUGHT THIS DAY WOULD COME', null, now() - interval '50 minutes'),
  ('d0000001-0000-0000-0000-000000000014', 'c0000001-0000-0000-0000-000000000009', 'da2955ad-a0ca-4955-9d8c-f1ce25f798a2',
   'Source 3 engine is going to change everything. The physics demo was wild.', null, now() - interval '40 minutes'),
  ('d0000001-0000-0000-0000-000000000015', 'c0000001-0000-0000-0000-000000000009', '6419e893-d23d-42c6-ab12-48ae110de9bf',
   'Gaben finally delivered. What a time to be alive.', null, now() - interval '35 minutes'),
  ('d0000001-0000-0000-0000-000000000016', 'c0000001-0000-0000-0000-000000000009', '9389df2a-0f12-46d7-ab57-25f237c3fd2a',
   'The Alyx storyline continuation is the real hype for me.', 'd0000001-0000-0000-0000-000000000014', now() - interval '25 minutes'),
  -- On Black Myth Wukong post
  ('d0000001-0000-0000-0000-000000000017', 'c0000001-0000-0000-0000-000000000005', '9389df2a-0f12-46d7-ab57-25f237c3fd2a',
   'DLC already?? Game Science working overtime.', null, now() - interval '5 hours'),
  ('d0000001-0000-0000-0000-000000000018', 'c0000001-0000-0000-0000-000000000005', '6419e893-d23d-42c6-ab12-48ae110de9bf',
   'The new weapon types look crazy. Dual wielding when??', null, now() - interval '4 hours'),
  ('d0000001-0000-0000-0000-000000000019', 'c0000001-0000-0000-0000-000000000005', 'da2955ad-a0ca-4955-9d8c-f1ce25f798a2',
   'Best action game of the decade. No debate.', 'd0000001-0000-0000-0000-000000000017', now() - interval '3 hours')
on conflict (id) do nothing;

-- ── 5. Update comment_count on post_metrics for existing posts ─────────

update public.post_metrics set comment_count = (
  select count(*) from public.comments where comments.post_id = post_metrics.post_id
)
where post_id in (
  'b0000001-0000-0000-0000-00000000000e',
  'b0000001-0000-0000-0000-000000000010',
  'b0000001-0000-0000-0000-000000000011',
  'b0000001-0000-0000-0000-000000000001'
);

commit;
