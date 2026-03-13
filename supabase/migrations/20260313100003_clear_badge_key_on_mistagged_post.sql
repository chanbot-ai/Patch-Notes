-- Clear primary_badge_key on the Mass Effect post that was incorrectly
-- inheriting RDR2's game via the badge key fallback in the game feed RPC.
UPDATE posts
SET primary_badge_key = NULL
WHERE source_external_id = 'reddit_1rpq1xc'
  AND title ILIKE '%Mass Effect%';
