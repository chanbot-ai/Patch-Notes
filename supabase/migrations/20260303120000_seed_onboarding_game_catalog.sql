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
  ('a1000001-0000-0000-0000-000000000001'::uuid, 'God of War Ragnarök',       NULL, 'Action Adventure',      'PlayStation',    '2022-11-09'),
  ('a1000001-0000-0000-0000-000000000002'::uuid, 'Spider-Man 2',              NULL, 'Action Adventure',      'PlayStation',    '2023-10-20'),
  ('a1000001-0000-0000-0000-000000000003'::uuid, 'Horizon Forbidden West',    NULL, 'Open World RPG',        'PlayStation',    '2022-02-18'),
  ('a1000001-0000-0000-0000-000000000004'::uuid, 'The Last of Us Part III',   NULL, 'Action Adventure',      'PlayStation',    NULL),
  ('a1000001-0000-0000-0000-000000000005'::uuid, 'Ghost of Tsushima 2',       NULL, 'Open World Action',     'PlayStation',    NULL),
  ('a1000001-0000-0000-0000-000000000006'::uuid, 'Gran Turismo 8',            NULL, 'Racing',                'PlayStation',    NULL),
  ('a1000001-0000-0000-0000-000000000007'::uuid, 'Astro Bot',                 NULL, 'Platformer',            'PlayStation',    '2024-09-06'),

  -- Xbox
  ('a2000001-0000-0000-0000-000000000001'::uuid, 'Fable',                     NULL, 'Action RPG',            'Xbox',           NULL),
  ('a2000001-0000-0000-0000-000000000002'::uuid, 'Avowed',                    NULL, 'First-Person RPG',      'Xbox',           '2025-02-18'),
  ('a2000001-0000-0000-0000-000000000003'::uuid, 'Gears 6',                   NULL, 'Third-Person Shooter',  'Xbox',           NULL),
  ('a2000001-0000-0000-0000-000000000004'::uuid, 'State of Decay 3',          NULL, 'Survival',              'Xbox',           NULL),
  ('a2000001-0000-0000-0000-000000000005'::uuid, 'Forza Motorsport 2',        NULL, 'Racing',                'Xbox',           NULL),
  ('a2000001-0000-0000-0000-000000000006'::uuid, 'Perfect Dark',              NULL, 'Action Shooter',        'Xbox',           NULL),

  -- Nintendo
  ('a3000001-0000-0000-0000-000000000001'::uuid, 'Metroid Prime 4: Beyond',   NULL, 'Action Adventure',      'Nintendo',       '2025-06-01'),
  ('a3000001-0000-0000-0000-000000000002'::uuid, 'Pokémon Legends: Z-A',      NULL, 'Action RPG',            'Nintendo',       '2025-11-01'),
  ('a3000001-0000-0000-0000-000000000003'::uuid, 'The Legend of Zelda',        NULL, 'Action Adventure',      'Nintendo',       NULL),
  ('a3000001-0000-0000-0000-000000000004'::uuid, 'Mario Kart 9',              NULL, 'Racing',                'Nintendo',       NULL),
  ('a3000001-0000-0000-0000-000000000005'::uuid, 'Splatoon 4',                NULL, 'Third-Person Shooter',  'Nintendo',       NULL),

  -- PC
  ('a4000001-0000-0000-0000-000000000001'::uuid, 'GTA VI',                    NULL, 'Open World Action',     'PC',             NULL),
  ('a4000001-0000-0000-0000-000000000002'::uuid, 'The Elder Scrolls VI',      NULL, 'Open World RPG',        'PC',             NULL),
  ('a4000001-0000-0000-0000-000000000003'::uuid, 'The Witcher 4',             NULL, 'Action RPG',            'PC',             NULL),
  ('a4000001-0000-0000-0000-000000000004'::uuid, 'Half-Life 3',               NULL, 'FPS',                   'PC',             NULL),
  ('a4000001-0000-0000-0000-000000000005'::uuid, 'Civilization VII',           NULL, 'Strategy',              'PC',             '2025-02-11'),
  ('a4000001-0000-0000-0000-000000000006'::uuid, 'Hollow Knight: Silksong',   NULL, 'Metroidvania',          'PC',             NULL),

  -- Multiplatform
  ('a5000001-0000-0000-0000-000000000001'::uuid, 'Crimson Desert',            NULL, 'Open World Action RPG', 'Multiplatform',  '2026-03-19'),
  ('a5000001-0000-0000-0000-000000000002'::uuid, 'Marathon',                  NULL, 'Extraction Shooter',    'Multiplatform',  NULL),
  ('a5000001-0000-0000-0000-000000000003'::uuid, 'Monster Hunter Wilds',      NULL, 'Action RPG',            'Multiplatform',  '2025-02-28'),
  ('a5000001-0000-0000-0000-000000000004'::uuid, 'Death Stranding 2',         NULL, 'Action Adventure',      'Multiplatform',  '2025-06-26'),
  ('a5000001-0000-0000-0000-000000000005'::uuid, 'Elden Ring Nightreign',     NULL, 'Action RPG',            'Multiplatform',  '2025-06-01'),
  ('a5000001-0000-0000-0000-000000000006'::uuid, 'Doom: The Dark Ages',       NULL, 'FPS',                   'Multiplatform',  '2025-05-13'),
  ('a5000001-0000-0000-0000-000000000007'::uuid, 'Assassin''s Creed Shadows', NULL, 'Action RPG',            'Multiplatform',  '2025-03-20'),
  ('a5000001-0000-0000-0000-000000000008'::uuid, 'Ghost of Yōtei',            NULL, 'Open World Action',     'Multiplatform',  NULL),
  ('a5000001-0000-0000-0000-000000000009'::uuid, 'Borderlands 4',             NULL, 'Looter Shooter',        'Multiplatform',  '2025-09-01'),
  ('a5000001-0000-0000-0000-00000000000a'::uuid, 'Resident Evil 9',           NULL, 'Survival Horror',       'Multiplatform',  NULL),
  ('a5000001-0000-0000-0000-00000000000b'::uuid, 'Split Fiction',             NULL, 'Co-op Adventure',       'Multiplatform',  '2025-03-06'),
  ('a5000001-0000-0000-0000-00000000000c'::uuid, 'Mafia: The Old Country',    NULL, 'Action Adventure',      'Multiplatform',  NULL),
  ('a5000001-0000-0000-0000-00000000000d'::uuid, 'Dying Light: The Beast',    NULL, 'Action Survival',       'Multiplatform',  NULL)
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
