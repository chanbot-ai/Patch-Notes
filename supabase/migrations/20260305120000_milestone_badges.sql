-- ============================================================
-- Milestone Badge System: display badges + fetch RPCs
-- ============================================================

-- 1. Table to store which milestone badges a user wants to display (up to 3)
CREATE TABLE IF NOT EXISTS public.user_display_badges (
    user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    badge_slug text NOT NULL,
    ordinal integer NOT NULL CHECK (ordinal BETWEEN 1 AND 3),
    created_at timestamptz DEFAULT now(),
    PRIMARY KEY (user_id, badge_slug),
    UNIQUE (user_id, ordinal)
);

ALTER TABLE public.user_display_badges ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read any display badges"
    ON public.user_display_badges FOR SELECT
    USING (true);

CREATE POLICY "Users can manage own display badges"
    ON public.user_display_badges FOR ALL
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- 2. RPC: Set user display badges (up to 3 slugs)
CREATE OR REPLACE FUNCTION public.set_user_display_badges(p_badge_slugs text[])
RETURNS void
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_uid uuid := auth.uid();
    i integer;
BEGIN
    -- Remove existing badges
    DELETE FROM public.user_display_badges WHERE user_id = v_uid;

    -- Insert new badges (up to 3)
    IF array_length(p_badge_slugs, 1) IS NOT NULL THEN
        FOR i IN 1..LEAST(array_length(p_badge_slugs, 1), 3) LOOP
            INSERT INTO public.user_display_badges (user_id, badge_slug, ordinal)
            VALUES (v_uid, p_badge_slugs[i], i);
        END LOOP;
    END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.set_user_display_badges(text[]) TO authenticated;

-- 3. RPC: Fetch display badges for multiple users (bulk)
CREATE OR REPLACE FUNCTION public.fetch_user_display_badges(p_user_ids uuid[])
RETURNS TABLE (
    user_id uuid,
    badge_slug text,
    ordinal integer
)
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = public, pg_temp
AS $$
    SELECT db.user_id, db.badge_slug, db.ordinal
    FROM public.user_display_badges db
    WHERE db.user_id = ANY(p_user_ids)
    ORDER BY db.user_id, db.ordinal;
$$;

GRANT EXECUTE ON FUNCTION public.fetch_user_display_badges(uuid[]) TO authenticated;
GRANT EXECUTE ON FUNCTION public.fetch_user_display_badges(uuid[]) TO anon;

-- 4. RPC: Fetch current user's milestones
CREATE OR REPLACE FUNCTION public.fetch_my_milestones()
RETURNS TABLE (
    comments_posted integer,
    replies_posted integer,
    reactions_given integer
)
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = public, pg_temp
AS $$
    SELECT m.comments_posted, m.replies_posted, m.reactions_given
    FROM public.user_milestones m
    WHERE m.user_id = auth.uid();
$$;

GRANT EXECUTE ON FUNCTION public.fetch_my_milestones() TO authenticated;

-- 5. Index for fast badge lookups
CREATE INDEX IF NOT EXISTS idx_user_display_badges_user_id
    ON public.user_display_badges (user_id);
