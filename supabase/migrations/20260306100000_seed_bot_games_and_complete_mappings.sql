-- ============================================================
-- Step 1.1: Seed missing games + complete bot→game mappings
-- ============================================================
-- Ensures every per-game bot has a corresponding game in the
-- catalog and a valid game_id in bot_content_sources.
-- Also adds Twitter source rows for the 7 specialty bots.

-- ============================
-- INSERT MISSING GAMES (a9 prefix)
-- ============================
INSERT INTO public.games (id, title, genre, category) VALUES
  ('a9000001-0000-0000-0000-000000000001', 'GTA V / GTA Online',       'Action',       'PC'),
  ('a9000001-0000-0000-0000-000000000002', 'League of Legends',        'MOBA',         'PC'),
  ('a9000001-0000-0000-0000-000000000003', 'Call of Duty',             'FPS',          'Multiplatform'),
  ('a9000001-0000-0000-0000-000000000004', 'Final Fantasy XIV',        'MMORPG',       'Multiplatform'),
  ('a9000001-0000-0000-0000-000000000005', 'World of Warcraft',        'MMORPG',       'PC'),
  ('a9000001-0000-0000-0000-000000000006', 'Overwatch 2',              'FPS',          'Multiplatform'),
  ('a9000001-0000-0000-0000-000000000007', 'Deadlock',                 'MOBA',         'PC'),
  ('a9000001-0000-0000-0000-000000000008', 'Call of Duty: Warzone',    'Battle Royale','Multiplatform'),
  ('a9000001-0000-0000-0000-000000000009', 'Rocket League',            'Sports',       'Multiplatform'),
  ('a9000001-0000-0000-0000-00000000000a', 'Helldivers 2',             'Co-op Shooter','Multiplatform'),
  ('a9000001-0000-0000-0000-00000000000b', 'Starfield',                'RPG',          'PC'),
  ('a9000001-0000-0000-0000-00000000000c', 'Mario',                    'Platformer',   'Nintendo'),
  ('a9000001-0000-0000-0000-00000000000d', 'Super Smash Bros.',        'Fighting',     'Nintendo'),
  ('a9000001-0000-0000-0000-00000000000e', 'Stardew Valley',           'Simulation',   'Multiplatform'),
  ('a9000001-0000-0000-0000-00000000000f', 'Terraria',                 'Sandbox',      'Multiplatform'),
  ('a9000001-0000-0000-0000-000000000010', 'EA Sports FC',             'Sports',       'Multiplatform'),
  ('a9000001-0000-0000-0000-000000000011', 'NBA 2K',                   'Sports',       'Multiplatform'),
  ('a9000001-0000-0000-0000-000000000012', 'Madden NFL',               'Sports',       'Multiplatform'),
  ('a9000001-0000-0000-0000-000000000013', 'Animal Crossing',          'Simulation',   'Nintendo'),
  ('a9000001-0000-0000-0000-000000000014', 'Genshin Impact',           'Action RPG',   'Multiplatform'),
  ('a9000001-0000-0000-0000-000000000015', 'Honkai: Star Rail',        'RPG',          'Multiplatform'),
  ('a9000001-0000-0000-0000-000000000016', 'Warframe',                 'Action',       'Multiplatform'),
  ('a9000001-0000-0000-0000-000000000017', 'No Man''s Sky',            'Survival',     'Multiplatform'),
  ('a9000001-0000-0000-0000-000000000018', 'Deep Rock Galactic',       'Co-op Shooter','Multiplatform'),
  ('a9000001-0000-0000-0000-000000000019', 'Lethal Company',           'Horror',       'PC'),
  ('a9000001-0000-0000-0000-00000000001a', 'Satisfactory',             'Factory Sim',  'PC'),
  ('a9000001-0000-0000-0000-00000000001b', 'ARK: Survival',            'Survival',     'Multiplatform'),
  ('a9000001-0000-0000-0000-00000000001c', 'DayZ',                     'Survival',     'Multiplatform'),
  ('a9000001-0000-0000-0000-00000000001d', 'Escape from Tarkov',       'FPS',          'PC'),
  ('a9000001-0000-0000-0000-00000000001e', 'Rainbow Six Siege',        'FPS',          'Multiplatform'),
  ('a9000001-0000-0000-0000-00000000001f', 'Dead by Daylight',         'Horror',       'Multiplatform'),
  ('a9000001-0000-0000-0000-000000000020', 'Path of Exile',            'Action RPG',   'PC')
ON CONFLICT (id) DO NOTHING;

-- ============================
-- COMPLETE game_id MAPPINGS FOR ALL 60 PER-GAME BOTS
-- ============================
-- Each bot_user_id → game_id mapping is explicit (no ILIKE).
-- Uses existing catalog UUIDs where games already existed, new a9 UUIDs for new games.

-- Tier 1: Massive
UPDATE public.bot_content_sources SET game_id = 'a7000001-0000-0000-0000-000000000001' WHERE bot_user_id = 'b0200000-0000-0000-0000-000000000001'; -- cs2_bot → Counter-Strike 2
UPDATE public.bot_content_sources SET game_id = 'a7000001-0000-0000-0000-000000000002' WHERE bot_user_id = 'b0200000-0000-0000-0000-000000000002'; -- dota2_bot → Dota 2
UPDATE public.bot_content_sources SET game_id = 'a7000001-0000-0000-0000-000000000003' WHERE bot_user_id = 'b0200000-0000-0000-0000-000000000003'; -- pubg_bot → PUBG
UPDATE public.bot_content_sources SET game_id = 'a7000001-0000-0000-0000-000000000004' WHERE bot_user_id = 'b0200000-0000-0000-0000-000000000004'; -- apex_bot → Apex Legends
UPDATE public.bot_content_sources SET game_id = 'a9000001-0000-0000-0000-000000000001' WHERE bot_user_id = 'b0200000-0000-0000-0000-000000000005'; -- gtav_bot → GTA V
UPDATE public.bot_content_sources SET game_id = 'a7000001-0000-0000-0000-000000000008' WHERE bot_user_id = 'b0200000-0000-0000-0000-000000000006'; -- rust_bot → Rust
UPDATE public.bot_content_sources SET game_id = 'a6000001-0000-0000-0000-000000000001' WHERE bot_user_id = 'b0200000-0000-0000-0000-000000000007'; -- elden_ring_bot → Elden Ring
UPDATE public.bot_content_sources SET game_id = 'a7000001-0000-0000-0000-000000000005' WHERE bot_user_id = 'b0200000-0000-0000-0000-000000000008'; -- fortnite_bot → Fortnite
UPDATE public.bot_content_sources SET game_id = 'a7000001-0000-0000-0000-000000000006' WHERE bot_user_id = 'b0200000-0000-0000-0000-000000000009'; -- valorant_bot → Valorant
UPDATE public.bot_content_sources SET game_id = 'a8000001-0000-0000-0000-000000000005' WHERE bot_user_id = 'b0200000-0000-0000-0000-000000000010'; -- minecraft_bot → Minecraft

-- Tier 2: Large
UPDATE public.bot_content_sources SET game_id = 'a9000001-0000-0000-0000-000000000002' WHERE bot_user_id = 'b0200000-0000-0000-0000-000000000011'; -- lol_bot → League of Legends
UPDATE public.bot_content_sources SET game_id = 'a9000001-0000-0000-0000-000000000003' WHERE bot_user_id = 'b0200000-0000-0000-0000-000000000012'; -- cod_bot → Call of Duty
UPDATE public.bot_content_sources SET game_id = 'a7000001-0000-0000-0000-00000000000a' WHERE bot_user_id = 'b0200000-0000-0000-0000-000000000013'; -- destiny2_bot → Destiny 2
UPDATE public.bot_content_sources SET game_id = 'a9000001-0000-0000-0000-000000000004' WHERE bot_user_id = 'b0200000-0000-0000-0000-000000000014'; -- ff14_bot → Final Fantasy XIV
UPDATE public.bot_content_sources SET game_id = 'a9000001-0000-0000-0000-000000000005' WHERE bot_user_id = 'b0200000-0000-0000-0000-000000000015'; -- wow_bot → World of Warcraft
UPDATE public.bot_content_sources SET game_id = 'a9000001-0000-0000-0000-000000000006' WHERE bot_user_id = 'b0200000-0000-0000-0000-000000000016'; -- overwatch_bot → Overwatch 2
UPDATE public.bot_content_sources SET game_id = 'a9000001-0000-0000-0000-000000000020' WHERE bot_user_id = 'b0200000-0000-0000-0000-000000000017'; -- poe_bot → Path of Exile
UPDATE public.bot_content_sources SET game_id = 'a9000001-0000-0000-0000-000000000007' WHERE bot_user_id = 'b0200000-0000-0000-0000-000000000018'; -- deadlock_bot → Deadlock
UPDATE public.bot_content_sources SET game_id = 'a9000001-0000-0000-0000-000000000008' WHERE bot_user_id = 'b0200000-0000-0000-0000-000000000019'; -- warzone_bot → Warzone
UPDATE public.bot_content_sources SET game_id = 'a9000001-0000-0000-0000-000000000009' WHERE bot_user_id = 'b0200000-0000-0000-0000-000000000020'; -- rocketleague_bot → Rocket League

-- Tier 3: Popular
UPDATE public.bot_content_sources SET game_id = 'a6000001-0000-0000-0000-000000000005' WHERE bot_user_id = 'b0200000-0000-0000-0000-000000000021'; -- bg3_bot → Baldur's Gate 3
UPDATE public.bot_content_sources SET game_id = 'a3000001-0000-0000-0000-000000000003' WHERE bot_user_id = 'b0200000-0000-0000-0000-000000000022'; -- zelda_bot → Zelda: TotK
UPDATE public.bot_content_sources SET game_id = 'a3000001-0000-0000-0000-000000000002' WHERE bot_user_id = 'b0200000-0000-0000-0000-000000000023'; -- pokemon_bot → Pokémon
UPDATE public.bot_content_sources SET game_id = 'a8000001-0000-0000-0000-000000000004' WHERE bot_user_id = 'b0200000-0000-0000-0000-000000000024'; -- palworld_bot → Palworld
UPDATE public.bot_content_sources SET game_id = 'a9000001-0000-0000-0000-00000000000a' WHERE bot_user_id = 'b0200000-0000-0000-0000-000000000025'; -- helldivers2_bot → Helldivers 2
UPDATE public.bot_content_sources SET game_id = 'a9000001-0000-0000-0000-00000000000b' WHERE bot_user_id = 'b0200000-0000-0000-0000-000000000026'; -- starfield_bot → Starfield
UPDATE public.bot_content_sources SET game_id = 'a8000001-0000-0000-0000-000000000008' WHERE bot_user_id = 'b0200000-0000-0000-0000-000000000027'; -- cyberpunk_bot → Cyberpunk 2077
UPDATE public.bot_content_sources SET game_id = 'a8000001-0000-0000-0000-000000000007' WHERE bot_user_id = 'b0200000-0000-0000-0000-000000000028'; -- rdr2_bot → Red Dead Redemption 2
UPDATE public.bot_content_sources SET game_id = 'a4000001-0000-0000-0000-000000000001' WHERE bot_user_id = 'b0200000-0000-0000-0000-000000000029'; -- gta6_bot → GTA VI
UPDATE public.bot_content_sources SET game_id = 'a9000001-0000-0000-0000-00000000000c' WHERE bot_user_id = 'b0200000-0000-0000-0000-000000000030'; -- mario_bot → Mario
UPDATE public.bot_content_sources SET game_id = 'a9000001-0000-0000-0000-00000000000d' WHERE bot_user_id = 'b0200000-0000-0000-0000-000000000031'; -- smash_bot → Super Smash Bros.
UPDATE public.bot_content_sources SET game_id = 'a8000001-0000-0000-0000-000000000001' WHERE bot_user_id = 'b0200000-0000-0000-0000-000000000032'; -- halo_bot → Halo Infinite
UPDATE public.bot_content_sources SET game_id = 'a1000001-0000-0000-0000-000000000002' WHERE bot_user_id = 'b0200000-0000-0000-0000-000000000033'; -- spider_man_bot → Spider-Man 2
UPDATE public.bot_content_sources SET game_id = 'a1000001-0000-0000-0000-000000000001' WHERE bot_user_id = 'b0200000-0000-0000-0000-000000000034'; -- god_of_war_bot → God of War Ragnarök
UPDATE public.bot_content_sources SET game_id = 'a8000001-0000-0000-0000-000000000003' WHERE bot_user_id = 'b0200000-0000-0000-0000-000000000035'; -- witcher_bot → The Witcher 3
UPDATE public.bot_content_sources SET game_id = 'a9000001-0000-0000-0000-00000000000e' WHERE bot_user_id = 'b0200000-0000-0000-0000-000000000036'; -- stardew_bot → Stardew Valley
UPDATE public.bot_content_sources SET game_id = 'a9000001-0000-0000-0000-00000000000f' WHERE bot_user_id = 'b0200000-0000-0000-0000-000000000037'; -- terraria_bot → Terraria
UPDATE public.bot_content_sources SET game_id = 'a8000001-0000-0000-0000-000000000002' WHERE bot_user_id = 'b0200000-0000-0000-0000-000000000038'; -- skyrim_bot → Skyrim
UPDATE public.bot_content_sources SET game_id = 'a9000001-0000-0000-0000-000000000010' WHERE bot_user_id = 'b0200000-0000-0000-0000-000000000039'; -- fifa_bot → EA Sports FC
UPDATE public.bot_content_sources SET game_id = 'a9000001-0000-0000-0000-000000000011' WHERE bot_user_id = 'b0200000-0000-0000-0000-000000000040'; -- nba2k_bot → NBA 2K
UPDATE public.bot_content_sources SET game_id = 'a9000001-0000-0000-0000-000000000012' WHERE bot_user_id = 'b0200000-0000-0000-0000-000000000041'; -- madden_bot → Madden NFL
UPDATE public.bot_content_sources SET game_id = 'a1000001-0000-0000-0000-000000000003' WHERE bot_user_id = 'b0200000-0000-0000-0000-000000000042'; -- horizon_bot → Horizon Forbidden West
UPDATE public.bot_content_sources SET game_id = 'a1000001-0000-0000-0000-000000000004' WHERE bot_user_id = 'b0200000-0000-0000-0000-000000000043'; -- tlou_bot → The Last of Us Part III
UPDATE public.bot_content_sources SET game_id = 'a6000001-0000-0000-0000-000000000007' WHERE bot_user_id = 'b0200000-0000-0000-0000-000000000044'; -- resident_evil_bot → Resident Evil 4
UPDATE public.bot_content_sources SET game_id = 'a6000001-0000-0000-0000-00000000000b' WHERE bot_user_id = 'b0200000-0000-0000-0000-000000000045'; -- final_fantasy_bot → Final Fantasy VII Rebirth
UPDATE public.bot_content_sources SET game_id = 'a5000001-0000-0000-0000-000000000003' WHERE bot_user_id = 'b0200000-0000-0000-0000-000000000046'; -- monster_hunter_bot → Monster Hunter Wilds
UPDATE public.bot_content_sources SET game_id = 'a3000001-0000-0000-0000-000000000005' WHERE bot_user_id = 'b0200000-0000-0000-0000-000000000047'; -- splatoon_bot → Splatoon 4
UPDATE public.bot_content_sources SET game_id = 'a9000001-0000-0000-0000-000000000013' WHERE bot_user_id = 'b0200000-0000-0000-0000-000000000048'; -- animal_crossing_bot → Animal Crossing
UPDATE public.bot_content_sources SET game_id = 'a9000001-0000-0000-0000-000000000014' WHERE bot_user_id = 'b0200000-0000-0000-0000-000000000049'; -- genshin_bot → Genshin Impact
UPDATE public.bot_content_sources SET game_id = 'a9000001-0000-0000-0000-000000000015' WHERE bot_user_id = 'b0200000-0000-0000-0000-000000000050'; -- honkai_bot → Honkai: Star Rail
UPDATE public.bot_content_sources SET game_id = 'a9000001-0000-0000-0000-000000000016' WHERE bot_user_id = 'b0200000-0000-0000-0000-000000000051'; -- warframe_bot → Warframe
UPDATE public.bot_content_sources SET game_id = 'a9000001-0000-0000-0000-000000000017' WHERE bot_user_id = 'b0200000-0000-0000-0000-000000000052'; -- no_mans_sky_bot → No Man's Sky
UPDATE public.bot_content_sources SET game_id = 'a9000001-0000-0000-0000-000000000018' WHERE bot_user_id = 'b0200000-0000-0000-0000-000000000053'; -- deep_rock_bot → Deep Rock Galactic
UPDATE public.bot_content_sources SET game_id = 'a9000001-0000-0000-0000-000000000019' WHERE bot_user_id = 'b0200000-0000-0000-0000-000000000054'; -- lethal_company_bot → Lethal Company
UPDATE public.bot_content_sources SET game_id = 'a9000001-0000-0000-0000-00000000001a' WHERE bot_user_id = 'b0200000-0000-0000-0000-000000000055'; -- satisfactory_bot → Satisfactory
UPDATE public.bot_content_sources SET game_id = 'a9000001-0000-0000-0000-00000000001b' WHERE bot_user_id = 'b0200000-0000-0000-0000-000000000056'; -- ark_bot → ARK: Survival
UPDATE public.bot_content_sources SET game_id = 'a9000001-0000-0000-0000-00000000001c' WHERE bot_user_id = 'b0200000-0000-0000-0000-000000000057'; -- dayz_bot → DayZ
UPDATE public.bot_content_sources SET game_id = 'a9000001-0000-0000-0000-00000000001d' WHERE bot_user_id = 'b0200000-0000-0000-0000-000000000058'; -- escape_tarkov_bot → Escape from Tarkov
UPDATE public.bot_content_sources SET game_id = 'a9000001-0000-0000-0000-00000000001e' WHERE bot_user_id = 'b0200000-0000-0000-0000-000000000059'; -- rainbow6_bot → Rainbow Six Siege
UPDATE public.bot_content_sources SET game_id = 'a9000001-0000-0000-0000-00000000001f' WHERE bot_user_id = 'b0200000-0000-0000-0000-000000000060'; -- dead_by_daylight_bot → Dead by Daylight

-- ============================
-- ADD TWITTER SOURCES FOR 7 SPECIALTY BOTS
-- ============================
-- These pull from X/Twitter for fast-moving news, rumors, and esports.
INSERT INTO public.bot_content_sources (bot_user_id, source_type, source_identifier) VALUES
  -- Breaking News → major gaming news outlets
  ('b0100000-0000-0000-0000-000000000001', 'twitter', 'IGN'),
  ('b0100000-0000-0000-0000-000000000001', 'twitter', 'GameSpot'),
  ('b0100000-0000-0000-0000-000000000001', 'twitter', 'Kotaku'),
  -- Rumor Mill → leakers and insiders
  ('b0100000-0000-0000-0000-000000000002', 'twitter', 'Wario64'),
  ('b0100000-0000-0000-0000-000000000002', 'twitter', 'nibaborern'),
  -- Esports Central
  ('b0100000-0000-0000-0000-000000000003', 'twitter', 'esaboreal'),
  ('b0100000-0000-0000-0000-000000000003', 'twitter', 'ABOREAL'),
  -- Today in Gaming → platform accounts
  ('b0100000-0000-0000-0000-000000000004', 'twitter', 'Xbox'),
  ('b0100000-0000-0000-0000-000000000004', 'twitter', 'PlayStation'),
  ('b0100000-0000-0000-0000-000000000004', 'twitter', 'NintendoAmerica'),
  -- Game Deals
  ('b0100000-0000-0000-0000-000000000006', 'twitter', 'Wario64'),
  -- Indie Spotlight
  ('b0100000-0000-0000-0000-000000000007', 'twitter', 'itch_io')
ON CONFLICT DO NOTHING;
