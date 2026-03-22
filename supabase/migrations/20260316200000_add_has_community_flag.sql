-- Add has_community flag to distinguish followable community games from catalog-only games.
-- Community games have active bots producing feed content and are followable.
-- Catalog-only games are browsable, viewable, and favoritable but not followable.

ALTER TABLE public.games
  ADD COLUMN IF NOT EXISTS has_community boolean NOT NULL DEFAULT false;

-- Backfill: any game with an active bot content source is a community game
UPDATE public.games
SET has_community = true
WHERE id IN (
  SELECT DISTINCT game_id
  FROM public.bot_content_sources
  WHERE game_id IS NOT NULL AND is_active = true
);

-- Also promote games with 10k+ Steam reviews (strong community signal)
UPDATE public.games
SET has_community = true
WHERE steam_review_count >= 10000
  AND has_community = false;

-- Partial index for fast community-game queries
CREATE INDEX IF NOT EXISTS idx_games_has_community
  ON public.games (has_community)
  WHERE has_community = true;

COMMENT ON COLUMN public.games.has_community IS
  'Whether this game has an active community (bot, followable). '
  'Games without this flag are catalog-only: browsable, viewable, favoritable.';
