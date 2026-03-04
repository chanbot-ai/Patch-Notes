-- =============================================================================
-- Migration: Fix seed posts — use hardcoded UID for claw@gmail.com
-- The previous migration (20260303170000) used a dynamic lookup from auth.users
-- which may have failed. This ensures all 20 test posts exist with the correct
-- author_id.
-- =============================================================================

DO $$
DECLARE
  v_user_id uuid := '7b42e0b9-dcd3-4e5c-9b2b-f6031a284117';
BEGIN

  -- Elden Ring (a6000001-...-001)
  INSERT INTO public.posts (id, author_id, game_id, type, title, body, is_system_generated, created_at) VALUES
    ('b0000001-0000-0000-0000-000000000001'::uuid, v_user_id, 'a6000001-0000-0000-0000-000000000001'::uuid, 'text', 'Shadow of the Erdtree DLC is a masterpiece', 'The level design in the DLC might be FromSoft''s best work. The Scadutree is absolutely massive and every corner has something new to discover.', false, now() - interval '2 hours'),
    ('b0000001-0000-0000-0000-000000000002'::uuid, v_user_id, 'a6000001-0000-0000-0000-000000000001'::uuid, 'text', 'Best Elden Ring build for beginners?', 'Starting my first playthrough — should I go strength or dex? Heard bleed builds are broken but I want the authentic experience.', false, now() - interval '6 hours')
  ON CONFLICT (id) DO UPDATE SET author_id = EXCLUDED.author_id;

  -- Baldur's Gate 3 (a6000001-...-005)
  INSERT INTO public.posts (id, author_id, game_id, type, title, body, is_system_generated, created_at) VALUES
    ('b0000001-0000-0000-0000-000000000003'::uuid, v_user_id, 'a6000001-0000-0000-0000-000000000005'::uuid, 'text', 'BG3 Patch 8 adds 12 new subclasses', 'Larian just dropped a massive patch — Barbarian gets Path of the Giant, Bard gets College of Dance. This game keeps getting better months after release.', false, now() - interval '3 hours'),
    ('b0000001-0000-0000-0000-000000000004'::uuid, v_user_id, 'a6000001-0000-0000-0000-000000000005'::uuid, 'text', 'Unpopular opinion: Karlach is overrated', 'Don''t get me wrong she''s great but Shadowheart''s character arc is way more compelling. The Shar/Selune conflict hits different.', false, now() - interval '12 hours')
  ON CONFLICT (id) DO UPDATE SET author_id = EXCLUDED.author_id;

  -- GTA VI (a4000001-...-001)
  INSERT INTO public.posts (id, author_id, game_id, type, title, body, is_system_generated, created_at) VALUES
    ('b0000001-0000-0000-0000-000000000005'::uuid, v_user_id, 'a4000001-0000-0000-0000-000000000001'::uuid, 'text', 'GTA VI trailer 2 breakdown: everything we spotted', 'Vice City looks insane in the new engine. The water physics alone are next gen. Also spotted what looks like a heist mission in the marina district.', false, now() - interval '1 hour'),
    ('b0000001-0000-0000-0000-000000000006'::uuid, v_user_id, 'a4000001-0000-0000-0000-000000000001'::uuid, 'text', 'Will GTA VI have crossplay?', 'Rockstar hasn''t confirmed but with the dual protagonist system it would be perfect for co-op. Anyone hear rumors about this?', false, now() - interval '18 hours')
  ON CONFLICT (id) DO UPDATE SET author_id = EXCLUDED.author_id;

  -- Monster Hunter Wilds (a5000001-...-003)
  INSERT INTO public.posts (id, author_id, game_id, type, title, body, is_system_generated, created_at) VALUES
    ('b0000001-0000-0000-0000-000000000007'::uuid, v_user_id, 'a5000001-0000-0000-0000-000000000003'::uuid, 'text', 'Monster Hunter Wilds beta impressions', 'The seamless zone transitions are a game changer. No more loading screens between areas. Combat feels snappier than World too.', false, now() - interval '4 hours'),
    ('b0000001-0000-0000-0000-000000000008'::uuid, v_user_id, 'a5000001-0000-0000-0000-000000000003'::uuid, 'text', 'New weapon type leaked for Wilds?', 'DataMiners found references to a "Tempest Blade" in the latest build. Could be the first new weapon class since Iceborne.', false, now() - interval '8 hours')
  ON CONFLICT (id) DO UPDATE SET author_id = EXCLUDED.author_id;

  -- Counter-Strike 2 (a7000001-...-001)
  INSERT INTO public.posts (id, author_id, game_id, type, title, body, is_system_generated, created_at) VALUES
    ('b0000001-0000-0000-0000-000000000009'::uuid, v_user_id, 'a7000001-0000-0000-0000-000000000001'::uuid, 'text', 'CS2 Major Copenhagen results are wild', 'FaZe vs Navi grand finals went to triple overtime on Inferno. This might be the best Major we''ve ever had. Esports is back.', false, now() - interval '5 hours'),
    ('b0000001-0000-0000-0000-00000000000a'::uuid, v_user_id, 'a7000001-0000-0000-0000-000000000001'::uuid, 'text', 'The new Dust 2 rework is controversial', 'They moved B site again and added a new connector from mid. Some pros love it but the casual community is divided.', false, now() - interval '10 hours')
  ON CONFLICT (id) DO UPDATE SET author_id = EXCLUDED.author_id;

  -- Cyberpunk 2077 (a8000001-...-008)
  INSERT INTO public.posts (id, author_id, game_id, type, title, body, is_system_generated, created_at) VALUES
    ('b0000001-0000-0000-0000-00000000000b'::uuid, v_user_id, 'a8000001-0000-0000-0000-000000000008'::uuid, 'text', 'Cyberpunk sequel reportedly in full production', 'CDPR Boston is apparently scaling up fast. Rumor is it''s set in a new city — possibly based on San Francisco. Unreal Engine 5 this time.', false, now() - interval '30 minutes'),
    ('b0000001-0000-0000-0000-00000000000c'::uuid, v_user_id, 'a8000001-0000-0000-0000-000000000008'::uuid, 'text', 'Best Cyberpunk 2077 builds after 2.1 patch', 'Netrunner is still OP but the new Sandevistan tech tree makes melee builds actually viable. Mantis blades + slow-mo = chef''s kiss.', false, now() - interval '14 hours')
  ON CONFLICT (id) DO UPDATE SET author_id = EXCLUDED.author_id;

  -- Minecraft (a8000001-...-005)
  INSERT INTO public.posts (id, author_id, game_id, type, title, body, is_system_generated, created_at) VALUES
    ('b0000001-0000-0000-0000-00000000000d'::uuid, v_user_id, 'a8000001-0000-0000-0000-000000000005'::uuid, 'text', 'Minecraft 1.22 adds the Pale Garden biome', 'The creaking mob is terrifying — it only moves when you''re not looking at it. Very Weeping Angels energy. The pale oak wood looks amazing for builds.', false, now() - interval '7 hours')
  ON CONFLICT (id) DO UPDATE SET author_id = EXCLUDED.author_id;

  -- Crimson Desert (a5000001-...-001)
  INSERT INTO public.posts (id, author_id, game_id, type, title, body, is_system_generated, created_at) VALUES
    ('b0000001-0000-0000-0000-00000000000e'::uuid, v_user_id, 'a5000001-0000-0000-0000-000000000001'::uuid, 'text', 'Crimson Desert gameplay deep dive — this could be GOTY', 'Pearl Abyss showed 40 minutes of uncut gameplay. The combat looks like a mix of Dragon''s Dogma and Black Desert. Open world scale is massive.', false, now() - interval '45 minutes'),
    ('b0000001-0000-0000-0000-00000000000f'::uuid, v_user_id, 'a5000001-0000-0000-0000-000000000001'::uuid, 'text', 'Crimson Desert vs Elden Ring Nightreign — which are you more hyped for?', 'Both dropping close together. CD looks more story-driven while Nightreign is co-op focused. I think CD takes it for solo players.', false, now() - interval '16 hours')
  ON CONFLICT (id) DO UPDATE SET author_id = EXCLUDED.author_id;

  -- Doom: The Dark Ages (a5000001-...-006)
  INSERT INTO public.posts (id, author_id, game_id, type, title, body, is_system_generated, created_at) VALUES
    ('b0000001-0000-0000-0000-000000000010'::uuid, v_user_id, 'a5000001-0000-0000-0000-000000000006'::uuid, 'text', 'Doom: The Dark Ages review scores are in — 92 on Metacritic', 'id Software has done it again. Medieval Doom sounds weird on paper but the dragon riding sections are apparently incredible.', false, now() - interval '2 hours')
  ON CONFLICT (id) DO UPDATE SET author_id = EXCLUDED.author_id;

  -- Red Dead Redemption 2 (a8000001-...-007)
  INSERT INTO public.posts (id, author_id, game_id, type, title, body, is_system_generated, created_at) VALUES
    ('b0000001-0000-0000-0000-000000000011'::uuid, v_user_id, 'a8000001-0000-0000-0000-000000000007'::uuid, 'text', 'RDR2 PC mods that completely transform the game', 'The photorealistic reshade + 4K texture pack makes this game look like it came out in 2025. Arthur''s model with HD hair physics is wild.', false, now() - interval '20 hours')
  ON CONFLICT (id) DO UPDATE SET author_id = EXCLUDED.author_id;

  -- Path of Exile 2 (a7000001-...-007)
  INSERT INTO public.posts (id, author_id, game_id, type, title, body, is_system_generated, created_at) VALUES
    ('b0000001-0000-0000-0000-000000000012'::uuid, v_user_id, 'a7000001-0000-0000-0000-000000000007'::uuid, 'text', 'PoE2 endgame is already deeper than most ARPGs', 'The atlas rework in early access is insane. Each map has unique mechanics now and the boss encounters are Souls-level challenging.', false, now() - interval '9 hours')
  ON CONFLICT (id) DO UPDATE SET author_id = EXCLUDED.author_id;

  -- Dark Souls (a8000001-...-006)
  INSERT INTO public.posts (id, author_id, game_id, type, title, body, is_system_generated, created_at) VALUES
    ('b0000001-0000-0000-0000-000000000013'::uuid, v_user_id, 'a8000001-0000-0000-0000-000000000006'::uuid, 'text', 'Just beat Ornstein and Smough for the first time', 'After 47 attempts I finally did it solo. Killed Ornstein first to get Smough''s hammer. This game really is the GOAT. My hands are shaking.', false, now() - interval '11 hours')
  ON CONFLICT (id) DO UPDATE SET author_id = EXCLUDED.author_id;

  -- Ensure post_metrics exist for all 20 posts
  INSERT INTO public.post_metrics (post_id, reaction_count, comment_count, hot_score) VALUES
    ('b0000001-0000-0000-0000-000000000001'::uuid, 34, 12, 85.0),
    ('b0000001-0000-0000-0000-000000000002'::uuid, 8, 23, 42.0),
    ('b0000001-0000-0000-0000-000000000003'::uuid, 67, 31, 92.0),
    ('b0000001-0000-0000-0000-000000000004'::uuid, 15, 48, 55.0),
    ('b0000001-0000-0000-0000-000000000005'::uuid, 112, 67, 98.0),
    ('b0000001-0000-0000-0000-000000000006'::uuid, 5, 8, 20.0),
    ('b0000001-0000-0000-0000-000000000007'::uuid, 45, 19, 78.0),
    ('b0000001-0000-0000-0000-000000000008'::uuid, 22, 14, 60.0),
    ('b0000001-0000-0000-0000-000000000009'::uuid, 89, 42, 95.0),
    ('b0000001-0000-0000-0000-00000000000a'::uuid, 31, 27, 68.0),
    ('b0000001-0000-0000-0000-00000000000b'::uuid, 73, 35, 90.0),
    ('b0000001-0000-0000-0000-00000000000c'::uuid, 19, 11, 38.0),
    ('b0000001-0000-0000-0000-00000000000d'::uuid, 28, 15, 65.0),
    ('b0000001-0000-0000-0000-00000000000e'::uuid, 96, 52, 97.0),
    ('b0000001-0000-0000-0000-00000000000f'::uuid, 14, 9, 35.0),
    ('b0000001-0000-0000-0000-000000000010'::uuid, 58, 28, 88.0),
    ('b0000001-0000-0000-0000-000000000011'::uuid, 11, 6, 25.0),
    ('b0000001-0000-0000-0000-000000000012'::uuid, 37, 20, 72.0),
    ('b0000001-0000-0000-0000-000000000013'::uuid, 42, 33, 75.0)
  ON CONFLICT (post_id) DO UPDATE
    SET hot_score = EXCLUDED.hot_score;

END $$;
