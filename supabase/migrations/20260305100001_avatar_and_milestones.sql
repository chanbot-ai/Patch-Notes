-- ============================================================
-- Avatar System + Per-User Milestone Tracking
-- ============================================================

-- 1. Add avatar_slug column to users table for predefined avatar selection
ALTER TABLE public.users
    ADD COLUMN IF NOT EXISTS avatar_slug text DEFAULT 'gamer_1';

-- 2. Milestone tracking table
CREATE TABLE IF NOT EXISTS public.user_milestones (
    user_id uuid PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
    comments_posted integer NOT NULL DEFAULT 0,
    replies_posted integer NOT NULL DEFAULT 0,
    reactions_given integer NOT NULL DEFAULT 0,
    time_spent_minutes integer NOT NULL DEFAULT 0,
    updated_at timestamptz DEFAULT now()
);

ALTER TABLE public.user_milestones ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read own milestones"
    ON public.user_milestones FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Service role full access to milestones"
    ON public.user_milestones FOR ALL
    USING (auth.role() = 'service_role');

-- Auto-create milestone row on user creation
CREATE OR REPLACE FUNCTION public.create_user_milestones_row()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
    INSERT INTO public.user_milestones (user_id)
    VALUES (new.id)
    ON CONFLICT (user_id) DO NOTHING;
    RETURN new;
END;
$$;

DROP TRIGGER IF EXISTS user_insert_milestones_trigger ON public.users;
CREATE TRIGGER user_insert_milestones_trigger
AFTER INSERT ON public.users
FOR EACH ROW
EXECUTE FUNCTION public.create_user_milestones_row();

-- Backfill milestone rows for existing users
INSERT INTO public.user_milestones (user_id)
SELECT id FROM public.users
ON CONFLICT (user_id) DO NOTHING;

-- 3. Trigger: increment comments_posted on comment insert
CREATE OR REPLACE FUNCTION public.increment_comment_milestone()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
    IF new.parent_comment_id IS NULL THEN
        UPDATE public.user_milestones
        SET comments_posted = comments_posted + 1, updated_at = now()
        WHERE user_id = new.user_id;
    ELSE
        UPDATE public.user_milestones
        SET replies_posted = replies_posted + 1, updated_at = now()
        WHERE user_id = new.user_id;
    END IF;
    RETURN new;
END;
$$;

DROP TRIGGER IF EXISTS comment_milestone_trigger ON public.comments;
CREATE TRIGGER comment_milestone_trigger
AFTER INSERT ON public.comments
FOR EACH ROW
EXECUTE FUNCTION public.increment_comment_milestone();

-- 4. Trigger: increment reactions_given on reaction insert
CREATE OR REPLACE FUNCTION public.increment_reaction_milestone()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
    UPDATE public.user_milestones
    SET reactions_given = reactions_given + 1, updated_at = now()
    WHERE user_id = new.user_id;
    RETURN new;
END;
$$;

DROP TRIGGER IF EXISTS reaction_milestone_trigger ON public.reactions;
CREATE TRIGGER reaction_milestone_trigger
AFTER INSERT ON public.reactions
FOR EACH ROW
EXECUTE FUNCTION public.increment_reaction_milestone();

-- 5. RPC: update avatar slug
CREATE OR REPLACE FUNCTION public.update_user_avatar(p_avatar_slug text)
RETURNS void
LANGUAGE sql
SECURITY INVOKER
AS $$
    UPDATE public.users SET avatar_slug = p_avatar_slug WHERE id = auth.uid();
$$;

GRANT EXECUTE ON FUNCTION public.update_user_avatar(text) TO authenticated;

-- 6. Add avatar_slug to the public profile view if it exists, otherwise expose via users directly
-- Note: PublicProfile already reads from users table, just need avatar_slug accessible
GRANT SELECT (avatar_slug) ON public.users TO authenticated;
GRANT SELECT (avatar_slug) ON public.users TO anon;
