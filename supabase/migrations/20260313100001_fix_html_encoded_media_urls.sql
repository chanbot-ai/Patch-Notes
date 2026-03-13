-- Fix media_url and thumbnail_url containing HTML-encoded ampersands from RSS parsing
UPDATE posts
SET media_url = replace(media_url, '&amp;', '&')
WHERE media_url LIKE '%&amp;%';

UPDATE posts
SET thumbnail_url = replace(thumbnail_url, '&amp;', '&')
WHERE thumbnail_url LIKE '%&amp;%';
