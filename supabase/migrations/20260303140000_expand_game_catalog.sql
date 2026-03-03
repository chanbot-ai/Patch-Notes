-- =============================================================================
-- Migration: Expand Game Catalog
-- Adds GOTY nominees (2022–2025), top Steam games, and classic titles.
-- Updates generic "The Legend of Zelda" to the specific TOTK GOTY entry.
-- =============================================================================

-- 1. Update generic Zelda entry → specific GOTY nominee
UPDATE public.games
  SET title           = 'The Legend of Zelda: Tears of the Kingdom',
      cover_image_url = 'https://upload.wikimedia.org/wikipedia/en/f/fb/The_Legend_of_Zelda_Tears_of_the_Kingdom_cover.jpg',
      genre           = 'Action Adventure',
      release_date    = '2023-05-12'
  WHERE id = 'a3000001-0000-0000-0000-000000000003';

-- 2. Insert new games
INSERT INTO public.games (id, title, cover_image_url, genre, category, release_date)
VALUES
  -- Award Winners (GOTY nominees not already in catalog)
  ('a6000001-0000-0000-0000-000000000001'::uuid, 'Elden Ring',                       'https://upload.wikimedia.org/wikipedia/en/b/b9/Elden_Ring_Box_art.jpg',                          'Action RPG',       'Award Winners', '2022-02-25'),
  ('a6000001-0000-0000-0000-000000000002'::uuid, 'A Plague Tale: Requiem',            'https://upload.wikimedia.org/wikipedia/en/a/ae/A_Plague_Tale_Requiem_cover_art.jpg',              'Action Adventure', 'Award Winners', '2022-10-18'),
  ('a6000001-0000-0000-0000-000000000003'::uuid, 'Stray',                             'https://upload.wikimedia.org/wikipedia/en/f/f1/Stray_cover_art.jpg',                              'Adventure',        'Award Winners', '2022-07-19'),
  ('a6000001-0000-0000-0000-000000000004'::uuid, 'Xenoblade Chronicles 3',            'https://upload.wikimedia.org/wikipedia/en/7/76/Xenoblade_3.png',                                  'JRPG',             'Award Winners', '2022-07-29'),
  ('a6000001-0000-0000-0000-000000000005'::uuid, 'Baldur''s Gate 3',                  'https://upload.wikimedia.org/wikipedia/en/1/12/Baldur%27s_Gate_3_cover_art.jpg',                  'RPG',              'Award Winners', '2023-08-03'),
  ('a6000001-0000-0000-0000-000000000006'::uuid, 'Alan Wake 2',                       'https://upload.wikimedia.org/wikipedia/en/e/ed/Alan_Wake_2_box_art.jpg',                          'Action Horror',    'Award Winners', '2023-10-27'),
  ('a6000001-0000-0000-0000-000000000007'::uuid, 'Resident Evil 4',                   'https://upload.wikimedia.org/wikipedia/en/d/df/Resident_Evil_4_remake_cover_art.jpg',             'Survival Horror',  'Award Winners', '2023-03-24'),
  ('a6000001-0000-0000-0000-000000000008'::uuid, 'Balatro',                           'https://upload.wikimedia.org/wikipedia/en/8/89/Balatro_cover.jpg',                                'Roguelike',        'Award Winners', '2024-02-20'),
  ('a6000001-0000-0000-0000-000000000009'::uuid, 'Black Myth: Wukong',                'https://upload.wikimedia.org/wikipedia/en/a/a6/Black_Myth_Wukong_cover_art.jpg',                  'Action RPG',       'Award Winners', '2024-08-20'),
  ('a6000001-0000-0000-0000-00000000000a'::uuid, 'Elden Ring: Shadow of the Erdtree', 'https://upload.wikimedia.org/wikipedia/en/b/b9/Elden_Ring_Box_art.jpg',                          'Action RPG',       'Award Winners', '2024-06-21'),
  ('a6000001-0000-0000-0000-00000000000b'::uuid, 'Final Fantasy VII Rebirth',         'https://upload.wikimedia.org/wikipedia/en/7/75/Boxart_for_Final_Fantasy_VII_Rebirth.png',         'JRPG',             'Award Winners', '2024-02-29'),
  ('a6000001-0000-0000-0000-00000000000c'::uuid, 'Clair Obscur: Expedition 33',       'https://upload.wikimedia.org/wikipedia/en/thumb/5/5a/Clair_Obscur%2C_Expedition_33_Cover_1.webp/272px-Clair_Obscur%2C_Expedition_33_Cover_1.webp.png', 'JRPG', 'Award Winners', '2025-04-24'),
  ('a6000001-0000-0000-0000-00000000000d'::uuid, 'Donkey Kong Bananza',               'https://upload.wikimedia.org/wikipedia/en/0/01/Donkey_Kong_Bananza_updated_box_art.png',         'Platformer',       'Award Winners', NULL),
  ('a6000001-0000-0000-0000-00000000000e'::uuid, 'Hades II',                          'https://upload.wikimedia.org/wikipedia/en/0/0c/Hades_2_cover_art.jpeg',                          'Roguelike',        'Award Winners', NULL),
  ('a6000001-0000-0000-0000-00000000000f'::uuid, 'Kingdom Come: Deliverance II',      'https://upload.wikimedia.org/wikipedia/en/3/32/Kingdom_Come_Deliverance_II.jpg',                  'Open World RPG',   'Award Winners', '2025-02-04'),

  -- Popular (top Steam / esports titles)
  ('a7000001-0000-0000-0000-000000000001'::uuid, 'Counter-Strike 2',      'https://upload.wikimedia.org/wikipedia/en/f/f2/CS2_Cover_Art.jpg',              'FPS',              'Popular', '2023-09-27'),
  ('a7000001-0000-0000-0000-000000000002'::uuid, 'Dota 2',                'https://upload.wikimedia.org/wikipedia/en/3/31/Dota_2_Steam_artwork.jpg',       'MOBA',             'Popular', '2013-07-09'),
  ('a7000001-0000-0000-0000-000000000003'::uuid, 'PUBG: Battlegrounds',   'https://upload.wikimedia.org/wikipedia/en/9/9f/Pubgbattlegrounds.png',          'Battle Royale',    'Popular', '2017-12-20'),
  ('a7000001-0000-0000-0000-000000000004'::uuid, 'Apex Legends',          'https://upload.wikimedia.org/wikipedia/en/d/db/Apex_legends_cover.jpg',         'Battle Royale',    'Popular', '2019-02-04'),
  ('a7000001-0000-0000-0000-000000000005'::uuid, 'Fortnite',              NULL,                                                                            'Battle Royale',    'Popular', '2017-07-25'),
  ('a7000001-0000-0000-0000-000000000006'::uuid, 'Valorant',              NULL,                                                                            'Tactical Shooter', 'Popular', '2020-06-02'),
  ('a7000001-0000-0000-0000-000000000007'::uuid, 'Path of Exile 2',       'https://upload.wikimedia.org/wikipedia/en/5/52/Path_of_Exile_2_cover_art.jpg',  'Action RPG',       'Popular', '2024-12-06'),
  ('a7000001-0000-0000-0000-000000000008'::uuid, 'Rust',                  NULL,                                                                            'Survival',         'Popular', '2018-02-08'),
  ('a7000001-0000-0000-0000-000000000009'::uuid, 'Marvel Rivals',         NULL,                                                                            'Hero Shooter',     'Popular', '2024-12-06'),
  ('a7000001-0000-0000-0000-00000000000a'::uuid, 'Destiny 2',            'https://upload.wikimedia.org/wikipedia/en/0/05/Destiny_2_%28artwork%29.jpg',     'Looter Shooter',   'Popular', '2017-09-06'),

  -- Classics
  ('a8000001-0000-0000-0000-000000000001'::uuid, 'Halo Infinite',             'https://upload.wikimedia.org/wikipedia/en/1/14/Halo_Infinite.png',                    'FPS',            'Classics', '2021-12-08'),
  ('a8000001-0000-0000-0000-000000000002'::uuid, 'The Elder Scrolls V: Skyrim', 'https://upload.wikimedia.org/wikipedia/en/1/15/The_Elder_Scrolls_V_Skyrim_cover.png', 'Open World RPG', 'Classics', '2011-11-11'),
  ('a8000001-0000-0000-0000-000000000003'::uuid, 'The Witcher 3: Wild Hunt',  'https://upload.wikimedia.org/wikipedia/en/0/0c/Witcher_3_cover_art.jpg',              'Action RPG',     'Classics', '2015-05-19'),
  ('a8000001-0000-0000-0000-000000000004'::uuid, 'Palworld',                  'https://upload.wikimedia.org/wikipedia/en/f/fb/Palworld_Steam_artwork.jpg',            'Survival',       'Classics', '2024-01-19')

ON CONFLICT (id) DO UPDATE
  SET category        = EXCLUDED.category,
      cover_image_url = COALESCE(EXCLUDED.cover_image_url, public.games.cover_image_url);
