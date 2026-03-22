-- ============================================================
-- Populate steam_app_id on games + add Steam news sources
-- ============================================================
-- Maps existing games to their Steam app IDs and creates
-- bot_content_sources rows with source_type='steam' so the
-- Cloudflare Worker fetches Steam News API alongside Reddit/Twitter.

-- ============================
-- SET steam_app_id ON EXISTING GAMES
-- ============================
-- Only games available on Steam get an app ID.
-- Console exclusives (Mario, Zelda, Pokemon, etc.) are skipped.

-- Tier 1: Massive
UPDATE public.games SET steam_app_id = 730    WHERE id = 'a7000001-0000-0000-0000-000000000001'; -- Counter-Strike 2
UPDATE public.games SET steam_app_id = 570    WHERE id = 'a7000001-0000-0000-0000-000000000002'; -- Dota 2
UPDATE public.games SET steam_app_id = 578080 WHERE id = 'a7000001-0000-0000-0000-000000000003'; -- PUBG
UPDATE public.games SET steam_app_id = 1172470 WHERE id = 'a7000001-0000-0000-0000-000000000004'; -- Apex Legends
UPDATE public.games SET steam_app_id = 271590 WHERE id = 'a9000001-0000-0000-0000-000000000001'; -- GTA V / GTA Online
UPDATE public.games SET steam_app_id = 252490 WHERE id = 'a7000001-0000-0000-0000-000000000008'; -- Rust
UPDATE public.games SET steam_app_id = 1245620 WHERE id = 'a6000001-0000-0000-0000-000000000001'; -- Elden Ring
-- Valorant is not on Steam (Riot launcher only), skip

-- Tier 2: Large
UPDATE public.games SET steam_app_id = 1599340 WHERE id = 'a7000001-0000-0000-0000-00000000000a'; -- Destiny 2
UPDATE public.games SET steam_app_id = 39210  WHERE id = 'a9000001-0000-0000-0000-000000000004'; -- Final Fantasy XIV
-- Overwatch 2 is not on Steam (Battle.net only), skip
UPDATE public.games SET steam_app_id = 1422450 WHERE id = 'a9000001-0000-0000-0000-000000000007'; -- Deadlock
UPDATE public.games SET steam_app_id = 252950 WHERE id = 'a9000001-0000-0000-0000-000000000009'; -- Rocket League
UPDATE public.games SET steam_app_id = 238960 WHERE id = 'a9000001-0000-0000-0000-000000000020'; -- Path of Exile

-- Tier 3: Popular (Steam-available only)
UPDATE public.games SET steam_app_id = 1086940 WHERE id = 'a6000001-0000-0000-0000-000000000005'; -- Baldur's Gate 3
UPDATE public.games SET steam_app_id = 1623730 WHERE id = 'a8000001-0000-0000-0000-000000000004'; -- Palworld
UPDATE public.games SET steam_app_id = 553850 WHERE id = 'a9000001-0000-0000-0000-00000000000a'; -- Helldivers 2
UPDATE public.games SET steam_app_id = 1716740 WHERE id = 'a9000001-0000-0000-0000-00000000000b'; -- Starfield
UPDATE public.games SET steam_app_id = 1091500 WHERE id = 'a8000001-0000-0000-0000-000000000008'; -- Cyberpunk 2077
UPDATE public.games SET steam_app_id = 1174180 WHERE id = 'a8000001-0000-0000-0000-000000000007'; -- Red Dead Redemption 2
UPDATE public.games SET steam_app_id = 292030 WHERE id = 'a8000001-0000-0000-0000-000000000003'; -- The Witcher 3
UPDATE public.games SET steam_app_id = 413150 WHERE id = 'a9000001-0000-0000-0000-00000000000e'; -- Stardew Valley
UPDATE public.games SET steam_app_id = 105600 WHERE id = 'a9000001-0000-0000-0000-00000000000f'; -- Terraria
UPDATE public.games SET steam_app_id = 72850  WHERE id = 'a8000001-0000-0000-0000-000000000002'; -- Skyrim
UPDATE public.games SET steam_app_id = 1240440 WHERE id = 'a8000001-0000-0000-0000-000000000001'; -- Halo Infinite
UPDATE public.games SET steam_app_id = 1888160 WHERE id = 'a6000001-0000-0000-0000-000000000007'; -- Resident Evil 4
UPDATE public.games SET steam_app_id = 2446550 WHERE id = 'a5000001-0000-0000-0000-000000000003'; -- Monster Hunter Wilds
UPDATE public.games SET steam_app_id = 230230 WHERE id = 'a9000001-0000-0000-0000-000000000016'; -- Warframe
UPDATE public.games SET steam_app_id = 275850 WHERE id = 'a9000001-0000-0000-0000-000000000017'; -- No Man's Sky
UPDATE public.games SET steam_app_id = 548430 WHERE id = 'a9000001-0000-0000-0000-000000000018'; -- Deep Rock Galactic
UPDATE public.games SET steam_app_id = 2195250 WHERE id = 'a9000001-0000-0000-0000-000000000019'; -- Lethal Company
UPDATE public.games SET steam_app_id = 526870 WHERE id = 'a9000001-0000-0000-0000-00000000001a'; -- Satisfactory
UPDATE public.games SET steam_app_id = 346110 WHERE id = 'a9000001-0000-0000-0000-00000000001b'; -- ARK: Survival Evolved
UPDATE public.games SET steam_app_id = 221100 WHERE id = 'a9000001-0000-0000-0000-00000000001c'; -- DayZ
-- Escape from Tarkov is not on Steam, skip
UPDATE public.games SET steam_app_id = 359550 WHERE id = 'a9000001-0000-0000-0000-00000000001e'; -- Rainbow Six Siege
UPDATE public.games SET steam_app_id = 381210 WHERE id = 'a9000001-0000-0000-0000-00000000001f'; -- Dead by Daylight
-- Minecraft is not on Steam (Java Edition uses its own launcher), skip

-- ============================
-- ADD STEAM NEWS SOURCES FOR PER-GAME BOTS
-- ============================
-- source_identifier = Steam app ID (string), same bot_user_id as Reddit sources.
-- Only added for games that have a steam_app_id and active patch notes/news feeds.
-- Focuses on games with the most active Steam news (live-service, frequent updates).

INSERT INTO public.bot_content_sources (bot_user_id, source_type, source_identifier, game_id) VALUES
  -- Tier 1: Massive live-service games (very active Steam news)
  ('b0200000-0000-0000-0000-000000000001', 'steam', '730',     'a7000001-0000-0000-0000-000000000001'), -- CS2
  ('b0200000-0000-0000-0000-000000000002', 'steam', '570',     'a7000001-0000-0000-0000-000000000002'), -- Dota 2
  ('b0200000-0000-0000-0000-000000000003', 'steam', '578080',  'a7000001-0000-0000-0000-000000000003'), -- PUBG
  ('b0200000-0000-0000-0000-000000000004', 'steam', '1172470', 'a7000001-0000-0000-0000-000000000004'), -- Apex Legends
  ('b0200000-0000-0000-0000-000000000006', 'steam', '252490',  'a7000001-0000-0000-0000-000000000008'), -- Rust
  ('b0200000-0000-0000-0000-000000000007', 'steam', '1245620', 'a6000001-0000-0000-0000-000000000001'), -- Elden Ring

  -- Tier 2: Large (frequent updates)
  ('b0200000-0000-0000-0000-000000000013', 'steam', '1599340', 'a7000001-0000-0000-0000-00000000000a'), -- Destiny 2
  ('b0200000-0000-0000-0000-000000000017', 'steam', '238960',  'a9000001-0000-0000-0000-000000000020'), -- Path of Exile
  ('b0200000-0000-0000-0000-000000000018', 'steam', '1422450', 'a9000001-0000-0000-0000-000000000007'), -- Deadlock

  -- Tier 3: Popular with active Steam news
  ('b0200000-0000-0000-0000-000000000025', 'steam', '553850',  'a9000001-0000-0000-0000-00000000000a'), -- Helldivers 2
  ('b0200000-0000-0000-0000-000000000027', 'steam', '1091500', 'a8000001-0000-0000-0000-000000000008'), -- Cyberpunk 2077
  ('b0200000-0000-0000-0000-000000000036', 'steam', '413150',  'a9000001-0000-0000-0000-00000000000e'), -- Stardew Valley
  ('b0200000-0000-0000-0000-000000000037', 'steam', '105600',  'a9000001-0000-0000-0000-00000000000f'), -- Terraria
  ('b0200000-0000-0000-0000-000000000051', 'steam', '230230',  'a9000001-0000-0000-0000-000000000016'), -- Warframe
  ('b0200000-0000-0000-0000-000000000052', 'steam', '275850',  'a9000001-0000-0000-0000-000000000017'), -- No Man's Sky
  ('b0200000-0000-0000-0000-000000000053', 'steam', '548430',  'a9000001-0000-0000-0000-000000000018'), -- Deep Rock Galactic
  ('b0200000-0000-0000-0000-000000000055', 'steam', '526870',  'a9000001-0000-0000-0000-00000000001a'), -- Satisfactory
  ('b0200000-0000-0000-0000-000000000057', 'steam', '221100',  'a9000001-0000-0000-0000-00000000001c'), -- DayZ
  ('b0200000-0000-0000-0000-000000000060', 'steam', '381210',  'a9000001-0000-0000-0000-00000000001f'), -- Dead by Daylight
  ('b0200000-0000-0000-0000-000000000021', 'steam', '1086940', 'a6000001-0000-0000-0000-000000000005'), -- Baldur's Gate 3
  ('b0200000-0000-0000-0000-000000000044', 'steam', '1888160', 'a6000001-0000-0000-0000-000000000007'), -- Resident Evil 4
  ('b0200000-0000-0000-0000-000000000046', 'steam', '2446550', 'a5000001-0000-0000-0000-000000000003')  -- Monster Hunter Wilds
ON CONFLICT DO NOTHING;
