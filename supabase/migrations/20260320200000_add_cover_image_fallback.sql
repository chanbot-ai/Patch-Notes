-- Add cover_image_fallback_url for games where library_600x900.jpg doesn't exist.
-- Steam's header_image URLs contain unique hashes that can't be constructed from app IDs,
-- so we store the API-provided URL during enrichment as a fallback.

ALTER TABLE public.games
  ADD COLUMN IF NOT EXISTS cover_image_fallback_url text;
