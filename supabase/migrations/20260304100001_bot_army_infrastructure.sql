-- ============================================================
-- Bot Army Infrastructure
-- Adds is_bot flag, creates bot profiles, maps bots to sources
-- ============================================================

-- 1. Add is_bot flag to profiles
ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS is_bot boolean NOT NULL DEFAULT false;

-- 2. Create bot_content_sources table (maps bots → subreddits/sources)
CREATE TABLE IF NOT EXISTS public.bot_content_sources (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    bot_user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    source_type text NOT NULL DEFAULT 'reddit',  -- reddit, steam, rss
    source_identifier text NOT NULL,              -- subreddit name, steam app id, rss url
    game_id uuid REFERENCES public.games(id) ON DELETE SET NULL,
    is_active boolean NOT NULL DEFAULT true,
    last_fetched_at timestamptz,
    created_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_bot_content_sources_bot ON public.bot_content_sources(bot_user_id);
CREATE INDEX IF NOT EXISTS idx_bot_content_sources_active ON public.bot_content_sources(is_active) WHERE is_active = true;

-- 3. Create bot_post_log for deduplication
CREATE TABLE IF NOT EXISTS public.bot_post_log (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    bot_user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    source_type text NOT NULL,
    source_external_id text NOT NULL,   -- reddit post id, etc.
    post_id uuid REFERENCES public.posts(id) ON DELETE SET NULL,
    created_at timestamptz DEFAULT now(),
    UNIQUE(source_type, source_external_id)
);

-- 4. RLS policies
ALTER TABLE public.bot_content_sources ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bot_post_log ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Bot content sources are readable by all"
  ON public.bot_content_sources FOR SELECT TO authenticated USING (true);

CREATE POLICY "Bot post log is readable by all"
  ON public.bot_post_log FOR SELECT TO authenticated USING (true);

-- 5. Create bot user accounts
-- Must insert into auth.users first (FK constraint), then update public.users profiles
-- The handle_new_user() trigger auto-creates public.users rows

-- Helper function to create a bot auth entry + update profile
CREATE OR REPLACE FUNCTION _create_bot(
  p_id uuid,
  p_username text,
  p_display_name text
) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = auth, public AS $$
BEGIN
  -- Create auth.users entry (minimal, no real password)
  INSERT INTO auth.users (
    id, instance_id, aud, role,
    email, encrypted_password,
    email_confirmed_at, created_at, updated_at,
    raw_app_meta_data, raw_user_meta_data,
    is_super_admin, confirmation_token
  ) VALUES (
    p_id,
    '00000000-0000-0000-0000-000000000000',
    'authenticated', 'authenticated',
    p_username || '@bot.patchnotes.local',
    '$2a$10$BOT.NOLOGIN.PLACEHOLDER.HASH.DONOTUSE000000000000000',
    now(), now(), now(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{}'::jsonb,
    false, ''
  ) ON CONFLICT (id) DO NOTHING;

  -- Update the auto-created public.users profile
  UPDATE public.users SET
    username = p_username,
    display_name = p_display_name,
    is_bot = true,
    onboarding_complete = true
  WHERE id = p_id;
END;
$$;

-- ============================
-- SPECIALTY BOTS (7)
-- ============================
SELECT _create_bot('b0100000-0000-0000-0000-000000000001', 'breaking_news_bot', '🚨 Breaking News');
SELECT _create_bot('b0100000-0000-0000-0000-000000000002', 'rumor_mill_bot', '🔮 Rumor Mill');
SELECT _create_bot('b0100000-0000-0000-0000-000000000003', 'esports_bot', '🏆 Esports Central');
SELECT _create_bot('b0100000-0000-0000-0000-000000000004', 'today_in_gaming_bot', '📅 Today in Gaming');
SELECT _create_bot('b0100000-0000-0000-0000-000000000005', 'poll_bot', '📊 Community Polls');
SELECT _create_bot('b0100000-0000-0000-0000-000000000006', 'deal_bot', '💰 Game Deals');
SELECT _create_bot('b0100000-0000-0000-0000-000000000007', 'indie_spotlight_bot', '🎮 Indie Spotlight');

-- ============================
-- PER-GAME BOTS (60)
-- Covers top Steam games by concurrent players + major AAA titles
-- ============================
-- Tier 1: Massive (>100K concurrent)
SELECT _create_bot('b0200000-0000-0000-0000-000000000001', 'cs2_bot', 'Counter-Strike 2');
SELECT _create_bot('b0200000-0000-0000-0000-000000000002', 'dota2_bot', 'Dota 2');
SELECT _create_bot('b0200000-0000-0000-0000-000000000003', 'pubg_bot', 'PUBG');
SELECT _create_bot('b0200000-0000-0000-0000-000000000004', 'apex_bot', 'Apex Legends');
SELECT _create_bot('b0200000-0000-0000-0000-000000000005', 'gtav_bot', 'GTA V / GTA Online');
SELECT _create_bot('b0200000-0000-0000-0000-000000000006', 'rust_bot', 'Rust');
SELECT _create_bot('b0200000-0000-0000-0000-000000000007', 'elden_ring_bot', 'Elden Ring');
SELECT _create_bot('b0200000-0000-0000-0000-000000000008', 'fortnite_bot', 'Fortnite');
SELECT _create_bot('b0200000-0000-0000-0000-000000000009', 'valorant_bot', 'Valorant');
SELECT _create_bot('b0200000-0000-0000-0000-000000000010', 'minecraft_bot', 'Minecraft');

-- Tier 2: Large (>30K concurrent or major franchises)
SELECT _create_bot('b0200000-0000-0000-0000-000000000011', 'lol_bot', 'League of Legends');
SELECT _create_bot('b0200000-0000-0000-0000-000000000012', 'cod_bot', 'Call of Duty');
SELECT _create_bot('b0200000-0000-0000-0000-000000000013', 'destiny2_bot', 'Destiny 2');
SELECT _create_bot('b0200000-0000-0000-0000-000000000014', 'ff14_bot', 'Final Fantasy XIV');
SELECT _create_bot('b0200000-0000-0000-0000-000000000015', 'wow_bot', 'World of Warcraft');
SELECT _create_bot('b0200000-0000-0000-0000-000000000016', 'overwatch_bot', 'Overwatch 2');
SELECT _create_bot('b0200000-0000-0000-0000-000000000017', 'poe_bot', 'Path of Exile');
SELECT _create_bot('b0200000-0000-0000-0000-000000000018', 'deadlock_bot', 'Deadlock');
SELECT _create_bot('b0200000-0000-0000-0000-000000000019', 'warzone_bot', 'Warzone');
SELECT _create_bot('b0200000-0000-0000-0000-000000000020', 'rocketleague_bot', 'Rocket League');

-- Tier 3: Popular (active communities, upcoming, or cult following)
SELECT _create_bot('b0200000-0000-0000-0000-000000000021', 'bg3_bot', 'Baldur''s Gate 3');
SELECT _create_bot('b0200000-0000-0000-0000-000000000022', 'zelda_bot', 'The Legend of Zelda');
SELECT _create_bot('b0200000-0000-0000-0000-000000000023', 'pokemon_bot', 'Pokémon');
SELECT _create_bot('b0200000-0000-0000-0000-000000000024', 'palworld_bot', 'Palworld');
SELECT _create_bot('b0200000-0000-0000-0000-000000000025', 'helldivers2_bot', 'Helldivers 2');
SELECT _create_bot('b0200000-0000-0000-0000-000000000026', 'starfield_bot', 'Starfield');
SELECT _create_bot('b0200000-0000-0000-0000-000000000027', 'cyberpunk_bot', 'Cyberpunk 2077');
SELECT _create_bot('b0200000-0000-0000-0000-000000000028', 'rdr2_bot', 'Red Dead Redemption 2');
SELECT _create_bot('b0200000-0000-0000-0000-000000000029', 'gta6_bot', 'GTA VI');
SELECT _create_bot('b0200000-0000-0000-0000-000000000030', 'mario_bot', 'Mario');
SELECT _create_bot('b0200000-0000-0000-0000-000000000031', 'smash_bot', 'Super Smash Bros.');
SELECT _create_bot('b0200000-0000-0000-0000-000000000032', 'halo_bot', 'Halo');
SELECT _create_bot('b0200000-0000-0000-0000-000000000033', 'spider_man_bot', 'Marvel''s Spider-Man');
SELECT _create_bot('b0200000-0000-0000-0000-000000000034', 'god_of_war_bot', 'God of War');
SELECT _create_bot('b0200000-0000-0000-0000-000000000035', 'witcher_bot', 'The Witcher');
SELECT _create_bot('b0200000-0000-0000-0000-000000000036', 'stardew_bot', 'Stardew Valley');
SELECT _create_bot('b0200000-0000-0000-0000-000000000037', 'terraria_bot', 'Terraria');
SELECT _create_bot('b0200000-0000-0000-0000-000000000038', 'skyrim_bot', 'Skyrim');
SELECT _create_bot('b0200000-0000-0000-0000-000000000039', 'fifa_bot', 'EA Sports FC');
SELECT _create_bot('b0200000-0000-0000-0000-000000000040', 'nba2k_bot', 'NBA 2K');
SELECT _create_bot('b0200000-0000-0000-0000-000000000041', 'madden_bot', 'Madden NFL');
SELECT _create_bot('b0200000-0000-0000-0000-000000000042', 'horizon_bot', 'Horizon');
SELECT _create_bot('b0200000-0000-0000-0000-000000000043', 'tlou_bot', 'The Last of Us');
SELECT _create_bot('b0200000-0000-0000-0000-000000000044', 'resident_evil_bot', 'Resident Evil');
SELECT _create_bot('b0200000-0000-0000-0000-000000000045', 'final_fantasy_bot', 'Final Fantasy');
SELECT _create_bot('b0200000-0000-0000-0000-000000000046', 'monster_hunter_bot', 'Monster Hunter');
SELECT _create_bot('b0200000-0000-0000-0000-000000000047', 'splatoon_bot', 'Splatoon');
SELECT _create_bot('b0200000-0000-0000-0000-000000000048', 'animal_crossing_bot', 'Animal Crossing');
SELECT _create_bot('b0200000-0000-0000-0000-000000000049', 'genshin_bot', 'Genshin Impact');
SELECT _create_bot('b0200000-0000-0000-0000-000000000050', 'honkai_bot', 'Honkai: Star Rail');
SELECT _create_bot('b0200000-0000-0000-0000-000000000051', 'warframe_bot', 'Warframe');
SELECT _create_bot('b0200000-0000-0000-0000-000000000052', 'no_mans_sky_bot', 'No Man''s Sky');
SELECT _create_bot('b0200000-0000-0000-0000-000000000053', 'deep_rock_bot', 'Deep Rock Galactic');
SELECT _create_bot('b0200000-0000-0000-0000-000000000054', 'lethal_company_bot', 'Lethal Company');
SELECT _create_bot('b0200000-0000-0000-0000-000000000055', 'satisfactory_bot', 'Satisfactory');
SELECT _create_bot('b0200000-0000-0000-0000-000000000056', 'ark_bot', 'ARK: Survival');
SELECT _create_bot('b0200000-0000-0000-0000-000000000057', 'dayz_bot', 'DayZ');
SELECT _create_bot('b0200000-0000-0000-0000-000000000058', 'escape_tarkov_bot', 'Escape from Tarkov');
SELECT _create_bot('b0200000-0000-0000-0000-000000000059', 'rainbow6_bot', 'Rainbow Six Siege');
SELECT _create_bot('b0200000-0000-0000-0000-000000000060', 'dead_by_daylight_bot', 'Dead by Daylight');

-- Drop the helper function (not needed after migration)
DROP FUNCTION IF EXISTS _create_bot(uuid, text, text);

-- ============================
-- MAP BOTS TO SUBREDDIT SOURCES
-- ============================
-- Specialty bots → multi-game subreddits
INSERT INTO public.bot_content_sources (bot_user_id, source_type, source_identifier) VALUES
  ('b0100000-0000-0000-0000-000000000001', 'reddit', 'Games'),
  ('b0100000-0000-0000-0000-000000000001', 'reddit', 'gaming'),
  ('b0100000-0000-0000-0000-000000000001', 'reddit', 'pcgaming'),
  ('b0100000-0000-0000-0000-000000000002', 'reddit', 'GamingLeaksAndRumours'),
  ('b0100000-0000-0000-0000-000000000002', 'reddit', 'gamingleaksandrumors'),
  ('b0100000-0000-0000-0000-000000000003', 'reddit', 'esports'),
  ('b0100000-0000-0000-0000-000000000003', 'reddit', 'CompetitiveOverwatch'),
  ('b0100000-0000-0000-0000-000000000004', 'reddit', 'todayinhistory'),
  ('b0100000-0000-0000-0000-000000000005', 'reddit', 'gaming'),
  ('b0100000-0000-0000-0000-000000000006', 'reddit', 'GameDeals'),
  ('b0100000-0000-0000-0000-000000000007', 'reddit', 'IndieGaming')
ON CONFLICT DO NOTHING;

-- Per-game bots → game-specific subreddits
INSERT INTO public.bot_content_sources (bot_user_id, source_type, source_identifier) VALUES
  ('b0200000-0000-0000-0000-000000000001', 'reddit', 'cs2'),
  ('b0200000-0000-0000-0000-000000000001', 'reddit', 'GlobalOffensive'),
  ('b0200000-0000-0000-0000-000000000002', 'reddit', 'DotA2'),
  ('b0200000-0000-0000-0000-000000000003', 'reddit', 'PUBATTLEGROUNDS'),
  ('b0200000-0000-0000-0000-000000000004', 'reddit', 'apexlegends'),
  ('b0200000-0000-0000-0000-000000000005', 'reddit', 'gtaonline'),
  ('b0200000-0000-0000-0000-000000000005', 'reddit', 'GrandTheftAutoV'),
  ('b0200000-0000-0000-0000-000000000006', 'reddit', 'playrust'),
  ('b0200000-0000-0000-0000-000000000007', 'reddit', 'Eldenring'),
  ('b0200000-0000-0000-0000-000000000008', 'reddit', 'FortNiteBR'),
  ('b0200000-0000-0000-0000-000000000009', 'reddit', 'VALORANT'),
  ('b0200000-0000-0000-0000-000000000010', 'reddit', 'Minecraft'),
  ('b0200000-0000-0000-0000-000000000011', 'reddit', 'leagueoflegends'),
  ('b0200000-0000-0000-0000-000000000012', 'reddit', 'ModernWarfareIII'),
  ('b0200000-0000-0000-0000-000000000013', 'reddit', 'DestinyTheGame'),
  ('b0200000-0000-0000-0000-000000000014', 'reddit', 'ffxiv'),
  ('b0200000-0000-0000-0000-000000000015', 'reddit', 'wow'),
  ('b0200000-0000-0000-0000-000000000016', 'reddit', 'Overwatch'),
  ('b0200000-0000-0000-0000-000000000017', 'reddit', 'pathofexile'),
  ('b0200000-0000-0000-0000-000000000018', 'reddit', 'DeadlockTheGame'),
  ('b0200000-0000-0000-0000-000000000020', 'reddit', 'RocketLeague'),
  ('b0200000-0000-0000-0000-000000000021', 'reddit', 'BaldursGate3'),
  ('b0200000-0000-0000-0000-000000000022', 'reddit', 'zelda'),
  ('b0200000-0000-0000-0000-000000000023', 'reddit', 'pokemon'),
  ('b0200000-0000-0000-0000-000000000024', 'reddit', 'Palworld'),
  ('b0200000-0000-0000-0000-000000000025', 'reddit', 'Helldivers'),
  ('b0200000-0000-0000-0000-000000000026', 'reddit', 'Starfield'),
  ('b0200000-0000-0000-0000-000000000027', 'reddit', 'cyberpunkgame'),
  ('b0200000-0000-0000-0000-000000000028', 'reddit', 'reddeadredemption'),
  ('b0200000-0000-0000-0000-000000000029', 'reddit', 'GTA6'),
  ('b0200000-0000-0000-0000-000000000030', 'reddit', 'Mario'),
  ('b0200000-0000-0000-0000-000000000031', 'reddit', 'smashbros'),
  ('b0200000-0000-0000-0000-000000000032', 'reddit', 'halo'),
  ('b0200000-0000-0000-0000-000000000033', 'reddit', 'SpidermanPS4'),
  ('b0200000-0000-0000-0000-000000000034', 'reddit', 'GodofWar'),
  ('b0200000-0000-0000-0000-000000000035', 'reddit', 'witcher'),
  ('b0200000-0000-0000-0000-000000000036', 'reddit', 'StardewValley'),
  ('b0200000-0000-0000-0000-000000000037', 'reddit', 'Terraria'),
  ('b0200000-0000-0000-0000-000000000038', 'reddit', 'skyrim'),
  ('b0200000-0000-0000-0000-000000000039', 'reddit', 'EASportsFC'),
  ('b0200000-0000-0000-0000-000000000040', 'reddit', 'NBA2k'),
  ('b0200000-0000-0000-0000-000000000041', 'reddit', 'Madden'),
  ('b0200000-0000-0000-0000-000000000042', 'reddit', 'horizon'),
  ('b0200000-0000-0000-0000-000000000043', 'reddit', 'thelastofus'),
  ('b0200000-0000-0000-0000-000000000044', 'reddit', 'residentevil'),
  ('b0200000-0000-0000-0000-000000000045', 'reddit', 'FinalFantasy'),
  ('b0200000-0000-0000-0000-000000000046', 'reddit', 'MonsterHunter'),
  ('b0200000-0000-0000-0000-000000000047', 'reddit', 'splatoon'),
  ('b0200000-0000-0000-0000-000000000048', 'reddit', 'AnimalCrossing'),
  ('b0200000-0000-0000-0000-000000000049', 'reddit', 'Genshin_Impact'),
  ('b0200000-0000-0000-0000-000000000050', 'reddit', 'HonkaiStarRail'),
  ('b0200000-0000-0000-0000-000000000051', 'reddit', 'Warframe'),
  ('b0200000-0000-0000-0000-000000000052', 'reddit', 'NoMansSkyTheGame'),
  ('b0200000-0000-0000-0000-000000000053', 'reddit', 'DeepRockGalactic'),
  ('b0200000-0000-0000-0000-000000000054', 'reddit', 'LethalCompany'),
  ('b0200000-0000-0000-0000-000000000055', 'reddit', 'SatisfactoryGame'),
  ('b0200000-0000-0000-0000-000000000056', 'reddit', 'ARK'),
  ('b0200000-0000-0000-0000-000000000057', 'reddit', 'dayz'),
  ('b0200000-0000-0000-0000-000000000058', 'reddit', 'EscapefromTarkov'),
  ('b0200000-0000-0000-0000-000000000059', 'reddit', 'Rainbow6'),
  ('b0200000-0000-0000-0000-000000000060', 'reddit', 'deadbydaylight')
ON CONFLICT DO NOTHING;

-- ============================
-- LINK BOTS TO GAMES (where game exists in catalog)
-- ============================
UPDATE public.bot_content_sources bcs
SET game_id = g.id
FROM public.games g
WHERE
  (bcs.bot_user_id = 'b0200000-0000-0000-0000-000000000006' AND g.title ILIKE '%Rust%')
  OR (bcs.bot_user_id = 'b0200000-0000-0000-0000-000000000007' AND g.title ILIKE '%Elden Ring%')
  OR (bcs.bot_user_id = 'b0200000-0000-0000-0000-000000000008' AND g.title ILIKE '%Fortnite%')
  OR (bcs.bot_user_id = 'b0200000-0000-0000-0000-000000000009' AND g.title ILIKE '%Valorant%')
  OR (bcs.bot_user_id = 'b0200000-0000-0000-0000-000000000021' AND g.title ILIKE '%Baldur%Gate%')
  OR (bcs.bot_user_id = 'b0200000-0000-0000-0000-000000000027' AND g.title ILIKE '%Cyberpunk%')
  OR (bcs.bot_user_id = 'b0200000-0000-0000-0000-000000000035' AND g.title ILIKE '%Witcher%')
  OR (bcs.bot_user_id = 'b0200000-0000-0000-0000-000000000038' AND g.title ILIKE '%Skyrim%')
  OR (bcs.bot_user_id = 'b0200000-0000-0000-0000-000000000044' AND g.title ILIKE '%Resident Evil%')
  OR (bcs.bot_user_id = 'b0200000-0000-0000-0000-000000000049' AND g.title ILIKE '%Genshin%');
