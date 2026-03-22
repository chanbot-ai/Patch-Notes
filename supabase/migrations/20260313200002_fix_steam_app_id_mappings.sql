-- ============================================================
-- Fix incorrect steam_app_id mappings + add missing games
-- ============================================================
-- Destiny 2 was mapped to 1599340 (Lost Ark), correct is 1085660.
-- Resident Evil 4 was mapped to 1888160 (Armored Core VI), correct is 2050650.
-- Clair Obscur: Expedition 33 was missing a mapping entirely.

-- Fix Destiny 2: 1599340 (Lost Ark) → 1085660 (Destiny 2)
UPDATE public.games
  SET steam_app_id = 1085660,
      cover_image_url = NULL,   -- clear wrong cover art so enrichment re-fetches
      enriched_at = NULL
  WHERE id = 'a7000001-0000-0000-0000-00000000000a';

-- Fix the Steam news source for Destiny 2
UPDATE public.bot_content_sources
  SET source_identifier = '1085660'
  WHERE bot_user_id = 'b0200000-0000-0000-0000-000000000013'
    AND source_type = 'steam'
    AND source_identifier = '1599340';

-- Fix Resident Evil 4: 1888160 (Armored Core VI) → 2050650 (RE4 Remake)
UPDATE public.games
  SET steam_app_id = 2050650,
      cover_image_url = NULL,
      enriched_at = NULL
  WHERE id = 'a6000001-0000-0000-0000-000000000007';

-- Fix the Steam news source for RE4
UPDATE public.bot_content_sources
  SET source_identifier = '2050650'
  WHERE bot_user_id = 'b0200000-0000-0000-0000-000000000044'
    AND source_type = 'steam'
    AND source_identifier = '1888160';

-- Add Clair Obscur: Expedition 33 (Steam app ID 1903340)
UPDATE public.games
  SET steam_app_id = 1903340,
      enriched_at = NULL
  WHERE id = 'a6000001-0000-0000-0000-00000000000c';
