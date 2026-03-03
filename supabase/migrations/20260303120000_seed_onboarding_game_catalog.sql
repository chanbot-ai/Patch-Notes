-- =============================================================================
-- Migration: Onboarding Game Catalog
-- Adds a category column to games for grouping during onboarding,
-- seeds a curated set of games, and creates a bulk-follow RPC.
-- =============================================================================

-- 1. Add category column for onboarding grouping
ALTER TABLE public.games ADD COLUMN IF NOT EXISTS category text;

-- 2. Seed onboarding game catalog with stable UUIDs
--    ON CONFLICT ensures idempotency for re-runs.
INSERT INTO public.games (id, title, cover_image_url, genre, category, release_date)
VALUES
  -- PlayStation
  ('a1000001-0000-0000-0000-000000000001'::uuid, 'God of War Ragnarök',       'https://upload.wikimedia.org/wikipedia/en/e/ee/God_of_War_Ragnar%C3%B6k_cover.jpg', 'Action Adventure',      'PlayStation',    '2022-11-09'),
  ('a1000001-0000-0000-0000-000000000002'::uuid, 'Spider-Man 2',              'https://upload.wikimedia.org/wikipedia/en/0/0f/SpiderMan2PS5BoxArt.jpeg', 'Action Adventure',      'PlayStation',    '2023-10-20'),
  ('a1000001-0000-0000-0000-000000000003'::uuid, 'Horizon Forbidden West',    'https://upload.wikimedia.org/wikipedia/en/6/69/Horizon_Forbidden_West_cover_art.jpg', 'Open World RPG',        'PlayStation',    '2022-02-18'),
  ('a1000001-0000-0000-0000-000000000004'::uuid, 'The Last of Us Part III',   NULL, 'Action Adventure',      'PlayStation',    NULL),
  ('a1000001-0000-0000-0000-000000000005'::uuid, 'Ghost of Tsushima 2',       NULL, 'Open World Action',     'PlayStation',    NULL),
  ('a1000001-0000-0000-0000-000000000006'::uuid, 'Gran Turismo 8',            NULL, 'Racing',                'PlayStation',    NULL),
  ('a1000001-0000-0000-0000-000000000007'::uuid, 'Astro Bot',                 'https://upload.wikimedia.org/wikipedia/en/a/a9/Astro_Bot_cover_art.jpg', 'Platformer',            'PlayStation',    '2024-09-06'),

  -- Xbox
  ('a2000001-0000-0000-0000-000000000001'::uuid, 'Fable',                     'https://upload.wikimedia.org/wikipedia/en/b/b8/Fable_key_art.png', 'Action RPG',            'Xbox',           NULL),
  ('a2000001-0000-0000-0000-000000000002'::uuid, 'Avowed',                    'https://upload.wikimedia.org/wikipedia/en/4/4d/Avowed_key_art.jpeg', 'First-Person RPG',      'Xbox',           '2025-02-18'),
  ('a2000001-0000-0000-0000-000000000003'::uuid, 'Gears 6',                   NULL, 'Third-Person Shooter',  'Xbox',           NULL),
  ('a2000001-0000-0000-0000-000000000004'::uuid, 'State of Decay 3',          NULL, 'Survival',              'Xbox',           NULL),
  ('a2000001-0000-0000-0000-000000000005'::uuid, 'Forza Motorsport 2',        NULL, 'Racing',                'Xbox',           NULL),
  ('a2000001-0000-0000-0000-000000000006'::uuid, 'Perfect Dark',              NULL, 'Action Shooter',        'Xbox',           NULL),

  -- Nintendo
  ('a3000001-0000-0000-0000-000000000001'::uuid, 'Metroid Prime 4: Beyond',   'https://upload.wikimedia.org/wikipedia/en/4/48/Metroid_Prime_4_Beyond_cover_art.png', 'Action Adventure',      'Nintendo',       '2025-06-01'),
  ('a3000001-0000-0000-0000-000000000002'::uuid, 'Pokémon Legends: Z-A',      'https://upload.wikimedia.org/wikipedia/en/thumb/2/2d/Pokemon_Legends_Z-A_Key_Art_Logo.png/500px-Pokemon_Legends_Z-A_Key_Art_Logo.png', 'Action RPG',            'Nintendo',       '2025-11-01'),
  ('a3000001-0000-0000-0000-000000000003'::uuid, 'The Legend of Zelda',        NULL, 'Action Adventure',      'Nintendo',       NULL),
  ('a3000001-0000-0000-0000-000000000004'::uuid, 'Mario Kart 9',              NULL, 'Racing',                'Nintendo',       NULL),
  ('a3000001-0000-0000-0000-000000000005'::uuid, 'Splatoon 4',                NULL, 'Third-Person Shooter',  'Nintendo',       NULL),

  -- PC
  ('a4000001-0000-0000-0000-000000000001'::uuid, 'GTA VI',                    'https://upload.wikimedia.org/wikipedia/en/4/46/Grand_Theft_Auto_VI.png', 'Open World Action',     'PC',             NULL),
  ('a4000001-0000-0000-0000-000000000002'::uuid, 'The Elder Scrolls VI',      NULL, 'Open World RPG',        'PC',             NULL),
  ('a4000001-0000-0000-0000-000000000003'::uuid, 'The Witcher 4',             NULL, 'Action RPG',            'PC',             NULL),
  ('a4000001-0000-0000-0000-000000000004'::uuid, 'Half-Life 3',               NULL, 'FPS',                   'PC',             NULL),
  ('a4000001-0000-0000-0000-000000000005'::uuid, 'Civilization VII',           'https://upload.wikimedia.org/wikipedia/en/d/d5/Civilization_VII_cover.png', 'Strategy',              'PC',             '2025-02-11'),
  ('a4000001-0000-0000-0000-000000000006'::uuid, 'Hollow Knight: Silksong',   'https://upload.wikimedia.org/wikipedia/en/0/05/Silksong.jpg', 'Metroidvania',          'PC',             NULL),

  -- Multiplatform
  ('a5000001-0000-0000-0000-000000000001'::uuid, 'Crimson Desert',            'https://upload.wikimedia.org/wikipedia/en/7/73/Crimson_Desert_Steam_Cover.jpg', 'Open World Action RPG', 'Multiplatform',  '2026-03-19'),
  ('a5000001-0000-0000-0000-000000000002'::uuid, 'Marathon',                  'https://upload.wikimedia.org/wikipedia/en/d/d0/Marathon_2026_box_art.png', 'Extraction Shooter',    'Multiplatform',  NULL),
  ('a5000001-0000-0000-0000-000000000003'::uuid, 'Monster Hunter Wilds',      'https://upload.wikimedia.org/wikipedia/en/5/52/Monster_Hunter_Wilds_cover.png', 'Action RPG',            'Multiplatform',  '2025-02-28'),
  ('a5000001-0000-0000-0000-000000000004'::uuid, 'Death Stranding 2',         'https://upload.wikimedia.org/wikipedia/en/e/e0/Death_Stranding_2_Icon.jpg', 'Action Adventure',      'Multiplatform',  '2025-06-26'),
  ('a5000001-0000-0000-0000-000000000005'::uuid, 'Elden Ring Nightreign',     'https://upload.wikimedia.org/wikipedia/en/f/f0/Elden_Ring_Nightreign_cover_art.png', 'Action RPG',            'Multiplatform',  '2025-06-01'),
  ('a5000001-0000-0000-0000-000000000006'::uuid, 'Doom: The Dark Ages',       'https://upload.wikimedia.org/wikipedia/en/7/7f/DOOM%2C_The_Dark_Ages_Game_Cover.jpeg', 'FPS',                   'Multiplatform',  '2025-05-13'),
  ('a5000001-0000-0000-0000-000000000007'::uuid, 'Assassin''s Creed Shadows', 'https://upload.wikimedia.org/wikipedia/en/5/54/Assassin%27s_Creed_Shadows_cover.png', 'Action RPG',            'Multiplatform',  '2025-03-20'),
  ('a5000001-0000-0000-0000-000000000008'::uuid, 'Ghost of Yōtei',            'https://upload.wikimedia.org/wikipedia/en/1/18/Ghost_of_Y%C5%8Dtei_cover_art.png', 'Open World Action',     'Multiplatform',  NULL),
  ('a5000001-0000-0000-0000-000000000009'::uuid, 'Borderlands 4',             'https://upload.wikimedia.org/wikipedia/en/f/fd/Borderlands_4_cover_art.jpg', 'Looter Shooter',        'Multiplatform',  '2025-09-01'),
  ('a5000001-0000-0000-0000-00000000000a'::uuid, 'Resident Evil 9',           NULL, 'Survival Horror',       'Multiplatform',  NULL),
  ('a5000001-0000-0000-0000-00000000000b'::uuid, 'Split Fiction',             'https://upload.wikimedia.org/wikipedia/en/4/40/Split_Fiction_cover_art.jpg', 'Co-op Adventure',       'Multiplatform',  '2025-03-06'),
  ('a5000001-0000-0000-0000-00000000000c'::uuid, 'Mafia: The Old Country',    'https://upload.wikimedia.org/wikipedia/en/a/af/Mafia_The_Old_Country_cover_art.jpg', 'Action Adventure',      'Multiplatform',  NULL),
  ('a5000001-0000-0000-0000-00000000000d'::uuid, 'Dying Light: The Beast',    'https://upload.wikimedia.org/wikipedia/en/d/db/Dying_Light_The_Beast_cover_art.jpg', 'Action Survival',       'Multiplatform',  NULL)
ON CONFLICT (id) DO UPDATE
  SET category = EXCLUDED.category,
      cover_image_url = COALESCE(EXCLUDED.cover_image_url, public.games.cover_image_url);


-- 3. Bulk-follow RPC for onboarding
--    Inserts multiple user_followed_games rows in one call.
CREATE OR REPLACE FUNCTION public.bulk_follow_games(
  p_user_id uuid,
  p_game_ids  uuid[]
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.user_followed_games (user_id, game_id)
  SELECT p_user_id, unnest(p_game_ids)
  ON CONFLICT (user_id, game_id) DO NOTHING;
END;
$$;

GRANT EXECUTE ON FUNCTION public.bulk_follow_games(uuid, uuid[]) TO authenticated;
