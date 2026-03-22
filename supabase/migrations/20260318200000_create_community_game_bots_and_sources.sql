-- ============================================================
-- Create bot accounts and Reddit content sources for all
-- community games that don't already have active sources.
-- ============================================================

-- Recreate the helper function (was dropped in earlier migration)
CREATE OR REPLACE FUNCTION _create_bot(
  p_id uuid,
  p_username text,
  p_display_name text
) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = auth, public AS $$
BEGIN
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

  UPDATE public.users SET
    username = p_username,
    display_name = p_display_name,
    is_bot = true,
    onboarding_complete = true
  WHERE id = p_id;
END;
$$;

-- ============================
-- STEP 1: Create 50 new bot accounts
-- (Deadlock already has a bot at b0200000-...-000000000018)
-- ============================

SELECT _create_bot('b0200000-0000-0000-0000-000000000061', 're_requiem_bot', 'Resident Evil Requiem');
SELECT _create_bot('b0200000-0000-0000-0000-000000000062', 'crimson_desert_bot', 'Crimson Desert');
SELECT _create_bot('b0200000-0000-0000-0000-000000000063', 'fable_bot', 'Fable');
SELECT _create_bot('b0200000-0000-0000-0000-000000000064', 'pragmata_bot', 'Pragmata');
SELECT _create_bot('b0200000-0000-0000-0000-000000000065', 'expedition33_bot', 'Clair Obscur: Expedition 33');
SELECT _create_bot('b0200000-0000-0000-0000-000000000066', 'subnautica2_bot', 'Subnautica 2');
SELECT _create_bot('b0200000-0000-0000-0000-000000000068', 'light_no_fire_bot', 'Light No Fire');
SELECT _create_bot('b0200000-0000-0000-0000-000000000069', 'forza_horizon6_bot', 'Forza Horizon 6');
SELECT _create_bot('b0200000-0000-0000-0000-000000000070', 'blight_survival_bot', 'Blight: Survival');
SELECT _create_bot('b0200000-0000-0000-0000-000000000071', 'kingmakers_bot', 'Kingmakers');
SELECT _create_bot('b0200000-0000-0000-0000-000000000072', 'windrose_bot', 'Windrose');
SELECT _create_bot('b0200000-0000-0000-0000-000000000073', 'ark2_bot', 'ARK 2');
SELECT _create_bot('b0200000-0000-0000-0000-000000000074', 'slay_spire2_bot', 'Slay the Spire 2');
SELECT _create_bot('b0200000-0000-0000-0000-000000000075', 'arc_raiders_bot', 'ARC Raiders');
SELECT _create_bot('b0200000-0000-0000-0000-000000000076', 'homm_bot', 'Heroes of Might and Magic');
SELECT _create_bot('b0200000-0000-0000-0000-000000000077', 'outbound_bot', 'Outbound');
SELECT _create_bot('b0200000-0000-0000-0000-000000000078', 'dow4_bot', 'Warhammer 40K: Dawn of War IV');
SELECT _create_bot('b0200000-0000-0000-0000-000000000079', 'tides_annihilation_bot', 'Tides of Annihilation');
SELECT _create_bot('b0200000-0000-0000-0000-000000000080', 'first_light_007_bot', '007 First Light');
SELECT _create_bot('b0200000-0000-0000-0000-000000000081', 'expanse_game_bot', 'The Expanse: Osiris Reborn');
SELECT _create_bot('b0200000-0000-0000-0000-000000000082', 'unrecord_bot', 'Unrecord');
SELECT _create_bot('b0200000-0000-0000-0000-000000000083', 'ill_game_bot', 'ILL');
SELECT _create_bot('b0200000-0000-0000-0000-000000000084', 'phantom_blade_bot', 'Phantom Blade Zero');
SELECT _create_bot('b0200000-0000-0000-0000-000000000085', 'pubg_blackbudget_bot', 'PUBG: Black Budget');
SELECT _create_bot('b0200000-0000-0000-0000-000000000086', 'over_the_hill_bot', 'over the hill');
SELECT _create_bot('b0200000-0000-0000-0000-000000000087', 'paralives_bot', 'Paralives');
SELECT _create_bot('b0200000-0000-0000-0000-000000000088', 'dead_as_disco_bot', 'Dead as Disco');
SELECT _create_bot('b0200000-0000-0000-0000-000000000089', 'witchbrook_bot', 'Witchbrook');
SELECT _create_bot('b0200000-0000-0000-0000-000000000090', 'mouse_pi_bot', 'MOUSE: P.I. For Hire');
SELECT _create_bot('b0200000-0000-0000-0000-000000000091', 'dawnwalker_bot', 'The Blood of Dawnwalker');
SELECT _create_bot('b0200000-0000-0000-0000-000000000092', 'rooted_bot', 'Rooted');
SELECT _create_bot('b0200000-0000-0000-0000-000000000093', 'tomb_raider_bot', 'Tomb Raider: Legacy of Atlantis');
SELECT _create_bot('b0200000-0000-0000-0000-000000000094', 'falling_frontier_bot', 'Falling Frontier');
SELECT _create_bot('b0200000-0000-0000-0000-000000000095', 'drg_rogue_core_bot', 'Deep Rock Galactic: Rogue Core');
SELECT _create_bot('b0200000-0000-0000-0000-000000000096', 'tw_warhammer40k_bot', 'Total War: WARHAMMER 40K');
SELECT _create_bot('b0200000-0000-0000-0000-000000000097', 'vindictus_bot', 'Vindictus: Defying Fate');
SELECT _create_bot('b0200000-0000-0000-0000-000000000098', 'solarpunk_bot', 'Solarpunk');
SELECT _create_bot('b0200000-0000-0000-0000-000000000099', 'onimusha_bot', 'Onimusha: Way of the Sword');
SELECT _create_bot('b0200000-0000-0000-0000-000000000100', 'burglin_gnomes_bot', 'Burglin'' Gnomes');
SELECT _create_bot('b0200000-0000-0000-0000-000000000101', 'persona4_revival_bot', 'Persona 4 Revival');
SELECT _create_bot('b0200000-0000-0000-0000-000000000102', 'gothic_remake_bot', 'Gothic 1 Remake');
SELECT _create_bot('b0200000-0000-0000-0000-000000000103', 'lego_batman_bot', 'LEGO Batman');
SELECT _create_bot('b0200000-0000-0000-0000-000000000104', 'fatekeeper_bot', 'Fatekeeper');
SELECT _create_bot('b0200000-0000-0000-0000-000000000105', 'bustling_world_bot', 'The Bustling World');
SELECT _create_bot('b0200000-0000-0000-0000-000000000106', 'nivalis_bot', 'Nivalis');
SELECT _create_bot('b0200000-0000-0000-0000-000000000107', 'chrono_odyssey_bot', 'Chrono Odyssey');
SELECT _create_bot('b0200000-0000-0000-0000-000000000108', 'replaced_bot', 'REPLACED');
SELECT _create_bot('b0200000-0000-0000-0000-000000000109', 'everwind_bot', 'Everwind');
SELECT _create_bot('b0200000-0000-0000-0000-000000000110', 'soulframe_bot', 'Soulframe');
SELECT _create_bot('b0200000-0000-0000-0000-000000000111', 'sand_raiders_bot', 'SAND: Raiders of Sophie');

-- Clean up the helper function
DROP FUNCTION IF EXISTS _create_bot(uuid, text, text);

-- ============================
-- STEP 2: Set avatar_slug on all new bot profiles
-- Cycle: bot_blue, bot_green, bot_red, bot_purple, bot_orange
-- ============================
UPDATE public.users SET avatar_slug = 'bot_blue'   WHERE id = 'b0200000-0000-0000-0000-000000000061';
UPDATE public.users SET avatar_slug = 'bot_green'  WHERE id = 'b0200000-0000-0000-0000-000000000062';
UPDATE public.users SET avatar_slug = 'bot_red'    WHERE id = 'b0200000-0000-0000-0000-000000000063';
UPDATE public.users SET avatar_slug = 'bot_purple' WHERE id = 'b0200000-0000-0000-0000-000000000064';
UPDATE public.users SET avatar_slug = 'bot_orange' WHERE id = 'b0200000-0000-0000-0000-000000000065';
UPDATE public.users SET avatar_slug = 'bot_blue'   WHERE id = 'b0200000-0000-0000-0000-000000000066';
UPDATE public.users SET avatar_slug = 'bot_red'    WHERE id = 'b0200000-0000-0000-0000-000000000068';
UPDATE public.users SET avatar_slug = 'bot_purple' WHERE id = 'b0200000-0000-0000-0000-000000000069';
UPDATE public.users SET avatar_slug = 'bot_orange' WHERE id = 'b0200000-0000-0000-0000-000000000070';
UPDATE public.users SET avatar_slug = 'bot_blue'   WHERE id = 'b0200000-0000-0000-0000-000000000071';
UPDATE public.users SET avatar_slug = 'bot_green'  WHERE id = 'b0200000-0000-0000-0000-000000000072';
UPDATE public.users SET avatar_slug = 'bot_red'    WHERE id = 'b0200000-0000-0000-0000-000000000073';
UPDATE public.users SET avatar_slug = 'bot_purple' WHERE id = 'b0200000-0000-0000-0000-000000000074';
UPDATE public.users SET avatar_slug = 'bot_orange' WHERE id = 'b0200000-0000-0000-0000-000000000075';
UPDATE public.users SET avatar_slug = 'bot_blue'   WHERE id = 'b0200000-0000-0000-0000-000000000076';
UPDATE public.users SET avatar_slug = 'bot_green'  WHERE id = 'b0200000-0000-0000-0000-000000000077';
UPDATE public.users SET avatar_slug = 'bot_red'    WHERE id = 'b0200000-0000-0000-0000-000000000078';
UPDATE public.users SET avatar_slug = 'bot_purple' WHERE id = 'b0200000-0000-0000-0000-000000000079';
UPDATE public.users SET avatar_slug = 'bot_orange' WHERE id = 'b0200000-0000-0000-0000-000000000080';
UPDATE public.users SET avatar_slug = 'bot_blue'   WHERE id = 'b0200000-0000-0000-0000-000000000081';
UPDATE public.users SET avatar_slug = 'bot_green'  WHERE id = 'b0200000-0000-0000-0000-000000000082';
UPDATE public.users SET avatar_slug = 'bot_red'    WHERE id = 'b0200000-0000-0000-0000-000000000083';
UPDATE public.users SET avatar_slug = 'bot_purple' WHERE id = 'b0200000-0000-0000-0000-000000000084';
UPDATE public.users SET avatar_slug = 'bot_orange' WHERE id = 'b0200000-0000-0000-0000-000000000085';
UPDATE public.users SET avatar_slug = 'bot_blue'   WHERE id = 'b0200000-0000-0000-0000-000000000086';
UPDATE public.users SET avatar_slug = 'bot_green'  WHERE id = 'b0200000-0000-0000-0000-000000000087';
UPDATE public.users SET avatar_slug = 'bot_red'    WHERE id = 'b0200000-0000-0000-0000-000000000088';
UPDATE public.users SET avatar_slug = 'bot_purple' WHERE id = 'b0200000-0000-0000-0000-000000000089';
UPDATE public.users SET avatar_slug = 'bot_orange' WHERE id = 'b0200000-0000-0000-0000-000000000090';
UPDATE public.users SET avatar_slug = 'bot_blue'   WHERE id = 'b0200000-0000-0000-0000-000000000091';
UPDATE public.users SET avatar_slug = 'bot_green'  WHERE id = 'b0200000-0000-0000-0000-000000000092';
UPDATE public.users SET avatar_slug = 'bot_red'    WHERE id = 'b0200000-0000-0000-0000-000000000093';
UPDATE public.users SET avatar_slug = 'bot_purple' WHERE id = 'b0200000-0000-0000-0000-000000000094';
UPDATE public.users SET avatar_slug = 'bot_orange' WHERE id = 'b0200000-0000-0000-0000-000000000095';
UPDATE public.users SET avatar_slug = 'bot_blue'   WHERE id = 'b0200000-0000-0000-0000-000000000096';
UPDATE public.users SET avatar_slug = 'bot_green'  WHERE id = 'b0200000-0000-0000-0000-000000000097';
UPDATE public.users SET avatar_slug = 'bot_red'    WHERE id = 'b0200000-0000-0000-0000-000000000098';
UPDATE public.users SET avatar_slug = 'bot_purple' WHERE id = 'b0200000-0000-0000-0000-000000000099';
UPDATE public.users SET avatar_slug = 'bot_orange' WHERE id = 'b0200000-0000-0000-0000-000000000100';
UPDATE public.users SET avatar_slug = 'bot_blue'   WHERE id = 'b0200000-0000-0000-0000-000000000101';
UPDATE public.users SET avatar_slug = 'bot_green'  WHERE id = 'b0200000-0000-0000-0000-000000000102';
UPDATE public.users SET avatar_slug = 'bot_red'    WHERE id = 'b0200000-0000-0000-0000-000000000103';
UPDATE public.users SET avatar_slug = 'bot_purple' WHERE id = 'b0200000-0000-0000-0000-000000000104';
UPDATE public.users SET avatar_slug = 'bot_orange' WHERE id = 'b0200000-0000-0000-0000-000000000105';
UPDATE public.users SET avatar_slug = 'bot_blue'   WHERE id = 'b0200000-0000-0000-0000-000000000106';
UPDATE public.users SET avatar_slug = 'bot_green'  WHERE id = 'b0200000-0000-0000-0000-000000000107';
UPDATE public.users SET avatar_slug = 'bot_red'    WHERE id = 'b0200000-0000-0000-0000-000000000108';
UPDATE public.users SET avatar_slug = 'bot_purple' WHERE id = 'b0200000-0000-0000-0000-000000000109';
UPDATE public.users SET avatar_slug = 'bot_orange' WHERE id = 'b0200000-0000-0000-0000-000000000110';
UPDATE public.users SET avatar_slug = 'bot_blue'   WHERE id = 'b0200000-0000-0000-0000-000000000111';

-- ============================
-- STEP 3: Create Reddit content sources for all new bots
-- ============================
INSERT INTO public.bot_content_sources (bot_user_id, source_type, source_identifier, game_id, is_active) VALUES
  ('b0200000-0000-0000-0000-000000000061', 'reddit', 'residentevil', '469734f9-3145-42bc-adbf-0b43b917cb46', true),
  ('b0200000-0000-0000-0000-000000000062', 'reddit', 'CrimsonDesert', '9a64b919-621f-4797-b101-35c5804e7c3b', true),
  ('b0200000-0000-0000-0000-000000000063', 'reddit', 'Fable', 'a2000001-0000-0000-0000-000000000001', true),
  ('b0200000-0000-0000-0000-000000000064', 'reddit', 'Pragmata', '107e7a1b-7698-4143-ac38-ab1b6206996f', true),
  ('b0200000-0000-0000-0000-000000000065', 'reddit', 'ClairObscur', 'a6000001-0000-0000-0000-00000000000c', true),
  ('b0200000-0000-0000-0000-000000000066', 'reddit', 'subnautica', 'd418e3db-5cfb-478f-845f-efe2ff055b0a', true),
  ('b0200000-0000-0000-0000-000000000068', 'reddit', 'LightNoFire', '0c3cd062-37da-43e4-8736-b70b23875d85', true),
  ('b0200000-0000-0000-0000-000000000069', 'reddit', 'ForzaHorizon', 'e3ba20fc-f1d1-4c15-811e-92698735812a', true),
  ('b0200000-0000-0000-0000-000000000070', 'reddit', 'BlightSurvival', '39e88e5f-9097-4bdf-ae23-f93112d468c8', true),
  ('b0200000-0000-0000-0000-000000000071', 'reddit', 'Kingmakers', '0e6c8521-30b3-420e-9811-48eef48702dc', true),
  ('b0200000-0000-0000-0000-000000000072', 'reddit', 'Windrose', '6822f200-fbd8-4110-80c6-4ee284f5b33e', true),
  ('b0200000-0000-0000-0000-000000000073', 'reddit', 'ARK', '6a7ada25-32ff-4d5f-b596-08c6e60f051b', true),
  ('b0200000-0000-0000-0000-000000000074', 'reddit', 'slaythespire', '41f3b511-125e-4c8b-afce-acc439cdfd2d', true),
  ('b0200000-0000-0000-0000-000000000075', 'reddit', 'ArcRaiders', 'bf123e8f-461b-4aa3-9927-15883692a007', true),
  ('b0200000-0000-0000-0000-000000000076', 'reddit', 'HoMM', '3c8cdbc9-6293-4b80-b617-a07457fd8167', true),
  ('b0200000-0000-0000-0000-000000000077', 'reddit', 'OutboundGame', 'cbfc78c0-379a-4f0a-8e45-db3801aabb77', true),
  ('b0200000-0000-0000-0000-000000000078', 'reddit', 'dawnofwar', 'be9fcedb-dda5-4428-8466-86cb54b7d783', true),
  ('b0200000-0000-0000-0000-000000000079', 'reddit', 'TidesOfAnnihilation', 'df2c64ac-98dc-48a7-b4fb-7dc706cf6cf3', true),
  ('b0200000-0000-0000-0000-000000000080', 'reddit', 'JamesBond', 'c5432178-7e7c-426f-a337-0a99fff9a0c4', true),
  ('b0200000-0000-0000-0000-000000000081', 'reddit', 'TheExpanseGame', '7c2d916a-c42a-42e3-aa38-e5b0699d3a98', true),
  ('b0200000-0000-0000-0000-000000000082', 'reddit', 'Unrecord', '1930ada9-42bb-4222-af38-5ab63dc518bd', true),
  ('b0200000-0000-0000-0000-000000000083', 'reddit', 'ILLgame', '069ca42f-fe51-4d18-bad3-65ad8e68f9a2', true),
  ('b0200000-0000-0000-0000-000000000084', 'reddit', 'PhantomBlade', 'e3999291-8c5d-47d8-98ce-254aca4ff959', true),
  ('b0200000-0000-0000-0000-000000000085', 'reddit', 'PUBATTLEGROUNDS', 'ea2fce34-18e7-4d4d-9cab-682f33ab81d8', true),
  ('b0200000-0000-0000-0000-000000000086', 'reddit', 'overthehill', '49a79565-75be-43bb-a7f0-59d794b02372', true),
  ('b0200000-0000-0000-0000-000000000087', 'reddit', 'Paralives', '12f90f8b-13b3-44ef-bf47-15b40abb7cd5', true),
  ('b0200000-0000-0000-0000-000000000088', 'reddit', 'DeadAsDisco', '49a2369f-79a8-4d49-a913-7befed3fcc63', true),
  ('b0200000-0000-0000-0000-000000000089', 'reddit', 'Witchbrook', '026376dd-8b01-4d83-933d-6d1b6be81970', true),
  ('b0200000-0000-0000-0000-000000000090', 'reddit', 'MOUSEgame', '9cd30c66-70e3-4312-a11a-91608eda29d3', true),
  ('b0200000-0000-0000-0000-000000000091', 'reddit', 'BloodOfDawnwalker', 'bd232d6f-052f-49bb-9e8b-f79665823b68', true),
  ('b0200000-0000-0000-0000-000000000092', 'reddit', 'RootedGame', 'fb2a37b0-b9d8-4261-bfce-6018bd498cf8', true),
  ('b0200000-0000-0000-0000-000000000093', 'reddit', 'TombRaider', '558560a8-439c-4118-b05b-11c26f7493e3', true),
  ('b0200000-0000-0000-0000-000000000094', 'reddit', 'FallingFrontier', 'fbc74d4a-7c48-4e0d-8b25-0e41006f2280', true),
  ('b0200000-0000-0000-0000-000000000095', 'reddit', 'DeepRockGalactic', 'e9ad6ff5-2913-45c1-8f40-20fc4bbc2d23', true),
  ('b0200000-0000-0000-0000-000000000096', 'reddit', 'totalwar', 'fbd0ed90-5485-4edf-b94f-552178ff3036', true),
  ('b0200000-0000-0000-0000-000000000097', 'reddit', 'Vindictus', '85635806-4d66-40b4-b62a-24fdee9500f8', true),
  ('b0200000-0000-0000-0000-000000000098', 'reddit', 'Solarpunk', 'ca9fef63-e98f-4355-a489-8e1c7221c6e9', true),
  ('b0200000-0000-0000-0000-000000000099', 'reddit', 'Onimusha', '26dfc07e-2242-4bc8-9773-7c820ee3af1f', true),
  ('b0200000-0000-0000-0000-000000000100', 'reddit', 'BurglinGnomes', '2c6c34db-4109-42ef-9414-14e0293dc4b0', true),
  ('b0200000-0000-0000-0000-000000000101', 'reddit', 'PERSoNA', 'a075a58f-60c2-4b74-892e-829de169cce3', true),
  ('b0200000-0000-0000-0000-000000000102', 'reddit', 'GothicGame', 'd51af55f-f781-4384-8733-96d81ae1c443', true),
  ('b0200000-0000-0000-0000-000000000103', 'reddit', 'legogaming', '2f1a0d68-301e-46be-a737-2bf625db7fbf', true),
  ('b0200000-0000-0000-0000-000000000104', 'reddit', 'Fatekeeper', '0e6022ae-f9ec-4181-9a60-1fc495e6cb85', true),
  ('b0200000-0000-0000-0000-000000000105', 'reddit', 'TheBustlingWorld', 'bb833872-8da7-4039-8e82-46313ddb55bb', true),
  ('b0200000-0000-0000-0000-000000000106', 'reddit', 'NivalisGame', 'f7c519b9-4030-42e7-a794-f68bbe372817', true),
  ('b0200000-0000-0000-0000-000000000107', 'reddit', 'ChronoOdyssey', '4bf8e9b8-fafe-4628-b782-e68b5ef0ed9e', true),
  ('b0200000-0000-0000-0000-000000000108', 'reddit', 'REPLACEDgame', '803f2639-6ed4-41b1-a2bd-538e8729bf2a', true),
  ('b0200000-0000-0000-0000-000000000109', 'reddit', 'Everwind', 'bdf6a02d-d07c-477b-9ad0-a1a50d8b065c', true),
  ('b0200000-0000-0000-0000-000000000110', 'reddit', 'Soulframe', '34aa8fbb-93df-4b4b-90ec-316349f8a175', true),
  ('b0200000-0000-0000-0000-000000000111', 'reddit', 'SANDgame', 'e0d65d03-0bef-46b5-a281-97a4537594cf', true)
ON CONFLICT DO NOTHING;

-- ============================
-- STEP 4: Fix Deadlock - update existing sources with correct game_id
-- ============================
UPDATE public.bot_content_sources
  SET game_id = '947d05a5-2d8f-4d22-add4-d505693eae35'
  WHERE bot_user_id = 'b0200000-0000-0000-0000-000000000018'
    AND game_id IS NULL;
