-- =============================================================================
-- Migration: Reorganize Catalog — Upcoming section, expanded Classics, cleanup
-- 1. Remove Elden Ring: Shadow of the Erdtree (redundant next to base game)
-- 2. Move Palworld → PC
-- 3. Move all unreleased games → Upcoming
-- 4. Add 6 classic cult-following titles
-- =============================================================================

-- 1. Remove Shadow of the Erdtree
DELETE FROM public.games WHERE id = 'a6000001-0000-0000-0000-00000000000a';

-- 2. Move Palworld from Classics → PC
UPDATE public.games SET category = 'PC'
  WHERE id = 'a8000001-0000-0000-0000-000000000004';

-- 3. Move unreleased / unannounced games → Upcoming
UPDATE public.games SET category = 'Upcoming' WHERE id IN (
  -- PlayStation
  'a1000001-0000-0000-0000-000000000004',  -- The Last of Us Part III
  'a1000001-0000-0000-0000-000000000005',  -- Ghost of Tsushima 2
  'a1000001-0000-0000-0000-000000000006',  -- Gran Turismo 8
  -- Xbox
  'a2000001-0000-0000-0000-000000000001',  -- Fable
  'a2000001-0000-0000-0000-000000000003',  -- Gears 6
  'a2000001-0000-0000-0000-000000000004',  -- State of Decay 3
  'a2000001-0000-0000-0000-000000000005',  -- Forza Motorsport 2
  'a2000001-0000-0000-0000-000000000006',  -- Perfect Dark
  -- Nintendo
  'a3000001-0000-0000-0000-000000000004',  -- Mario Kart 9
  'a3000001-0000-0000-0000-000000000005',  -- Splatoon 4
  -- PC
  'a4000001-0000-0000-0000-000000000001',  -- GTA VI
  'a4000001-0000-0000-0000-000000000002',  -- The Elder Scrolls VI
  'a4000001-0000-0000-0000-000000000003',  -- The Witcher 4
  'a4000001-0000-0000-0000-000000000004',  -- Half-Life 3
  -- Multiplatform
  'a5000001-0000-0000-0000-000000000001',  -- Crimson Desert
  'a5000001-0000-0000-0000-000000000002',  -- Marathon
  'a5000001-0000-0000-0000-000000000008',  -- Ghost of Yōtei
  'a5000001-0000-0000-0000-00000000000a',  -- Resident Evil 9
  'a5000001-0000-0000-0000-00000000000c',  -- Mafia: The Old Country
  'a5000001-0000-0000-0000-00000000000d'   -- Dying Light: The Beast
);

-- 4. Add classic cult-following titles
INSERT INTO public.games (id, title, cover_image_url, genre, category, release_date)
VALUES
  ('a8000001-0000-0000-0000-000000000005'::uuid, 'Minecraft',                    'https://upload.wikimedia.org/wikipedia/en/b/b6/Minecraft_2024_cover_art.png',            'Sandbox',        'Classics', '2011-11-18'),
  ('a8000001-0000-0000-0000-000000000006'::uuid, 'Dark Souls',                   'https://upload.wikimedia.org/wikipedia/en/8/8d/Dark_Souls_Cover_Art.jpg',                 'Action RPG',     'Classics', '2011-09-22'),
  ('a8000001-0000-0000-0000-000000000007'::uuid, 'Red Dead Redemption 2',        'https://upload.wikimedia.org/wikipedia/en/4/44/Red_Dead_Redemption_II.jpg',               'Open World',     'Classics', '2018-10-26'),
  ('a8000001-0000-0000-0000-000000000008'::uuid, 'Cyberpunk 2077',               'https://upload.wikimedia.org/wikipedia/en/9/9f/Cyberpunk_2077_box_art.jpg',               'Action RPG',     'Classics', '2020-12-10'),
  ('a8000001-0000-0000-0000-000000000009'::uuid, 'Bloodborne',                   'https://upload.wikimedia.org/wikipedia/en/6/68/Bloodborne_Cover_Wallpaper.jpg',            'Action RPG',     'Classics', '2015-03-24'),
  ('a8000001-0000-0000-0000-00000000000a'::uuid, 'Mass Effect Legendary Edition', 'https://upload.wikimedia.org/wikipedia/en/9/97/Mass_Effect_Legendary_Edition.jpeg',       'Sci-Fi RPG',     'Classics', '2021-05-14')
ON CONFLICT (id) DO UPDATE
  SET category        = EXCLUDED.category,
      cover_image_url = COALESCE(EXCLUDED.cover_image_url, public.games.cover_image_url);
