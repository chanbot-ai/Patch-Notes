-- Fix posts that were tagged with the wrong game because they came from a
-- game-specific subreddit but are actually about a different game.
-- Strategy: if a post's title mentions a different known game than the one
-- it's tagged with, clear the game_id so it appears as game-agnostic.

-- Specifically fix the "Mass Effect 4 Story Details Leaked" post from r/reddeadredemption
UPDATE posts
SET game_id = NULL
WHERE source_external_id = 'reddit_1rpq1xc'
  AND title ILIKE '%Mass Effect%';
