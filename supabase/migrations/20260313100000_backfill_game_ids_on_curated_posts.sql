-- Backfill game_id on curated posts where the title mentions a known game.
-- Uses longest-match-first to avoid partial matches (e.g., "Half-Life" vs "Half-Life 3").
WITH matches AS (
  SELECT p.id AS post_id, g.id AS game_id,
         ROW_NUMBER() OVER (PARTITION BY p.id ORDER BY length(g.title) DESC) AS rn
  FROM posts p
  JOIN games g ON p.title ILIKE '%' || g.title || '%'
  WHERE p.game_id IS NULL
    AND p.source_kind = 'curated'
)
UPDATE posts
SET game_id = m.game_id
FROM matches m
WHERE posts.id = m.post_id AND m.rn = 1;
