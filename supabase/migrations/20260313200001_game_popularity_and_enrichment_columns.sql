-- ============================================================
-- Add Steam enrichment + popularity gating columns to games
-- ============================================================
-- These columns are populated by the Worker's /enrich endpoint
-- using Steam app details + review APIs.

-- Review count is the primary signal for pill gating (threshold: 10,000).
-- For unreleased games without reviews, presence in Steam's "Coming Soon"
-- featured list is the discovery signal (handled by Worker logic).

ALTER TABLE public.games
  ADD COLUMN IF NOT EXISTS steam_review_count integer,
  ADD COLUMN IF NOT EXISTS steam_review_score text,
  ADD COLUMN IF NOT EXISTS metacritic_score integer,
  ADD COLUMN IF NOT EXISTS enriched_at timestamptz;

-- Index for fast popularity lookups (e.g. "show only popular games")
CREATE INDEX IF NOT EXISTS idx_games_steam_review_count
  ON public.games (steam_review_count DESC NULLS LAST)
  WHERE steam_review_count IS NOT NULL;

COMMENT ON COLUMN public.games.steam_review_count IS 'Total Steam review count. Used for pill gating: games with >= 10,000 reviews auto-qualify for community pills.';
COMMENT ON COLUMN public.games.steam_review_score IS 'Steam review sentiment label (e.g. Very Positive, Mostly Positive).';
COMMENT ON COLUMN public.games.metacritic_score IS 'Metacritic score from Steam app details (0-100).';
