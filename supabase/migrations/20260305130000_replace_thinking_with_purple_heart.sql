-- Replace "Thinking" (🤔) with "Purple Heart" (💜) in core reactions

-- Step 1: Reassign any existing reactions on the social purple_heart to the
-- thinking type (which we're about to convert to purple_heart core).
-- Delete duplicates first: if a user reacted with BOTH types on the same post,
-- keep only the thinking one and remove the social purple_heart one.
DELETE FROM public.reactions r
WHERE r.reaction_type_id = (SELECT id FROM public.reaction_types WHERE slug = 'purple_heart' AND category = 'social')
  AND EXISTS (
      SELECT 1 FROM public.reactions r2
      WHERE r2.post_id = r.post_id
        AND r2.user_id = r.user_id
        AND r2.reaction_type_id = (SELECT id FROM public.reaction_types WHERE slug = 'thinking')
  );

-- Also handle comment_reactions duplicates
DELETE FROM public.comment_reactions cr
WHERE cr.reaction_type_id = (SELECT id FROM public.reaction_types WHERE slug = 'purple_heart' AND category = 'social')
  AND EXISTS (
      SELECT 1 FROM public.comment_reactions cr2
      WHERE cr2.comment_id = cr.comment_id
        AND cr2.user_id = cr.user_id
        AND cr2.reaction_type_id = (SELECT id FROM public.reaction_types WHERE slug = 'thinking')
  );

-- Now safely reassign remaining social purple_heart reactions to thinking type
UPDATE public.reactions
SET reaction_type_id = (SELECT id FROM public.reaction_types WHERE slug = 'thinking')
WHERE reaction_type_id = (SELECT id FROM public.reaction_types WHERE slug = 'purple_heart' AND category = 'social');

UPDATE public.comment_reactions
SET reaction_type_id = (SELECT id FROM public.reaction_types WHERE slug = 'thinking')
WHERE reaction_type_id = (SELECT id FROM public.reaction_types WHERE slug = 'purple_heart' AND category = 'social');

-- Step 2: Remove the social purple_heart now that it has no references
DELETE FROM public.reaction_types
WHERE slug = 'purple_heart' AND category = 'social';

-- Step 3: Convert thinking to purple heart in core
UPDATE public.reaction_types
SET slug = 'purple_heart',
    display_name = 'Purple Heart',
    emoji = '💜'
WHERE slug = 'thinking';
