-- Replace "Thinking" (🤔) with "Purple Heart" (💜) in core reactions

-- Step 1: Reassign any existing reactions on the social purple_heart to the
-- thinking type (which we're about to convert to purple_heart core).
UPDATE public.reactions
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
