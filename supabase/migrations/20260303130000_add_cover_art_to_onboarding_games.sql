-- =============================================================================
-- Migration: Add Cover Art URLs to Onboarding Game Catalog
-- Populates cover_image_url for seeded games using publicly-hosted artwork.
-- Games without confirmed cover art retain NULL (placeholder shown in-app).
-- =============================================================================

-- PlayStation
UPDATE public.games SET cover_image_url = 'https://upload.wikimedia.org/wikipedia/en/e/ee/God_of_War_Ragnar%C3%B6k_cover.jpg'
  WHERE id = 'a1000001-0000-0000-0000-000000000001';

UPDATE public.games SET cover_image_url = 'https://upload.wikimedia.org/wikipedia/en/0/0f/SpiderMan2PS5BoxArt.jpeg'
  WHERE id = 'a1000001-0000-0000-0000-000000000002';

UPDATE public.games SET cover_image_url = 'https://upload.wikimedia.org/wikipedia/en/6/69/Horizon_Forbidden_West_cover_art.jpg'
  WHERE id = 'a1000001-0000-0000-0000-000000000003';

UPDATE public.games SET cover_image_url = 'https://upload.wikimedia.org/wikipedia/en/a/a9/Astro_Bot_cover_art.jpg'
  WHERE id = 'a1000001-0000-0000-0000-000000000007';

-- Xbox
UPDATE public.games SET cover_image_url = 'https://upload.wikimedia.org/wikipedia/en/b/b8/Fable_key_art.png'
  WHERE id = 'a2000001-0000-0000-0000-000000000001';

UPDATE public.games SET cover_image_url = 'https://upload.wikimedia.org/wikipedia/en/4/4d/Avowed_key_art.jpeg'
  WHERE id = 'a2000001-0000-0000-0000-000000000002';

-- Nintendo
UPDATE public.games SET cover_image_url = 'https://upload.wikimedia.org/wikipedia/en/4/48/Metroid_Prime_4_Beyond_cover_art.png'
  WHERE id = 'a3000001-0000-0000-0000-000000000001';

UPDATE public.games SET cover_image_url = 'https://upload.wikimedia.org/wikipedia/en/thumb/2/2d/Pokemon_Legends_Z-A_Key_Art_Logo.png/500px-Pokemon_Legends_Z-A_Key_Art_Logo.png'
  WHERE id = 'a3000001-0000-0000-0000-000000000002';

-- PC
UPDATE public.games SET cover_image_url = 'https://upload.wikimedia.org/wikipedia/en/4/46/Grand_Theft_Auto_VI.png'
  WHERE id = 'a4000001-0000-0000-0000-000000000001';

UPDATE public.games SET cover_image_url = 'https://upload.wikimedia.org/wikipedia/en/d/d5/Civilization_VII_cover.png'
  WHERE id = 'a4000001-0000-0000-0000-000000000005';

UPDATE public.games SET cover_image_url = 'https://upload.wikimedia.org/wikipedia/en/0/05/Silksong.jpg'
  WHERE id = 'a4000001-0000-0000-0000-000000000006';

-- Multiplatform
UPDATE public.games SET cover_image_url = 'https://upload.wikimedia.org/wikipedia/en/7/73/Crimson_Desert_Steam_Cover.jpg'
  WHERE id = 'a5000001-0000-0000-0000-000000000001';

UPDATE public.games SET cover_image_url = 'https://upload.wikimedia.org/wikipedia/en/d/d0/Marathon_2026_box_art.png'
  WHERE id = 'a5000001-0000-0000-0000-000000000002';

UPDATE public.games SET cover_image_url = 'https://upload.wikimedia.org/wikipedia/en/5/52/Monster_Hunter_Wilds_cover.png'
  WHERE id = 'a5000001-0000-0000-0000-000000000003';

UPDATE public.games SET cover_image_url = 'https://upload.wikimedia.org/wikipedia/en/e/e0/Death_Stranding_2_Icon.jpg'
  WHERE id = 'a5000001-0000-0000-0000-000000000004';

UPDATE public.games SET cover_image_url = 'https://upload.wikimedia.org/wikipedia/en/f/f0/Elden_Ring_Nightreign_cover_art.png'
  WHERE id = 'a5000001-0000-0000-0000-000000000005';

UPDATE public.games SET cover_image_url = 'https://upload.wikimedia.org/wikipedia/en/7/7f/DOOM%2C_The_Dark_Ages_Game_Cover.jpeg'
  WHERE id = 'a5000001-0000-0000-0000-000000000006';

UPDATE public.games SET cover_image_url = 'https://upload.wikimedia.org/wikipedia/en/5/54/Assassin%27s_Creed_Shadows_cover.png'
  WHERE id = 'a5000001-0000-0000-0000-000000000007';

UPDATE public.games SET cover_image_url = 'https://upload.wikimedia.org/wikipedia/en/1/18/Ghost_of_Y%C5%8Dtei_cover_art.png'
  WHERE id = 'a5000001-0000-0000-0000-000000000008';

UPDATE public.games SET cover_image_url = 'https://upload.wikimedia.org/wikipedia/en/f/fd/Borderlands_4_cover_art.jpg'
  WHERE id = 'a5000001-0000-0000-0000-000000000009';

UPDATE public.games SET cover_image_url = 'https://upload.wikimedia.org/wikipedia/en/4/40/Split_Fiction_cover_art.jpg'
  WHERE id = 'a5000001-0000-0000-0000-00000000000b';

UPDATE public.games SET cover_image_url = 'https://upload.wikimedia.org/wikipedia/en/a/af/Mafia_The_Old_Country_cover_art.jpg'
  WHERE id = 'a5000001-0000-0000-0000-00000000000c';

UPDATE public.games SET cover_image_url = 'https://upload.wikimedia.org/wikipedia/en/d/db/Dying_Light_The_Beast_cover_art.jpg'
  WHERE id = 'a5000001-0000-0000-0000-00000000000d';
