-- ============================================================
-- Ensure realtime tables are in the supabase_realtime publication,
-- add reply-to-reply notification support
-- ============================================================

-- Add post_metrics to realtime publication (for feed reaction updates)
DO $$
BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.post_metrics;
EXCEPTION
    WHEN duplicate_object THEN NULL;
END;
$$;

-- Add comment_metrics to realtime publication (for comment reaction updates)
DO $$
BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.comment_metrics;
EXCEPTION
    WHEN duplicate_object THEN NULL;
END;
$$;

-- Add comments to realtime publication (for real-time new comment sync)
DO $$
BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.comments;
EXCEPTION
    WHEN duplicate_object THEN NULL;
END;
$$;

-- ============================================================
-- Reply-to-reply notification support
-- ============================================================

-- Track which specific reply a comment is responding to (separate from threading)
ALTER TABLE public.comments
    ADD COLUMN IF NOT EXISTS reply_to_comment_id uuid REFERENCES public.comments(id) ON DELETE SET NULL;

-- Update notification trigger to also notify the reply_to_comment_id author
CREATE OR REPLACE FUNCTION public.create_notifications_for_comment()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    post_owner_id uuid;
    parent_comment_owner_id uuid;
    reply_to_owner_id uuid;
    notified_ids uuid[] := '{}';
BEGIN
    -- 1. Notify post owner
    SELECT p.author_id INTO post_owner_id
    FROM public.posts p WHERE p.id = new.post_id;

    IF post_owner_id IS NOT NULL
       AND post_owner_id <> new.user_id THEN
        INSERT INTO public.notifications (user_id, actor_user_id, post_id, comment_id, type)
        VALUES (post_owner_id, new.user_id, new.post_id, new.id, 'post_comment');
        notified_ids := array_append(notified_ids, post_owner_id);
    END IF;

    -- 2. Notify parent comment owner (for direct replies)
    IF new.parent_comment_id IS NOT NULL THEN
        SELECT c.user_id INTO parent_comment_owner_id
        FROM public.comments c WHERE c.id = new.parent_comment_id;

        IF parent_comment_owner_id IS NOT NULL
           AND parent_comment_owner_id <> new.user_id
           AND NOT (parent_comment_owner_id = ANY(notified_ids)) THEN
            INSERT INTO public.notifications (user_id, actor_user_id, post_id, comment_id, type)
            VALUES (parent_comment_owner_id, new.user_id, new.post_id, new.id, 'comment_reply');
            notified_ids := array_append(notified_ids, parent_comment_owner_id);
        END IF;
    END IF;

    -- 3. Notify reply_to_comment owner (for reply-to-reply)
    IF new.reply_to_comment_id IS NOT NULL THEN
        SELECT c.user_id INTO reply_to_owner_id
        FROM public.comments c WHERE c.id = new.reply_to_comment_id;

        IF reply_to_owner_id IS NOT NULL
           AND reply_to_owner_id <> new.user_id
           AND NOT (reply_to_owner_id = ANY(notified_ids)) THEN
            INSERT INTO public.notifications (user_id, actor_user_id, post_id, comment_id, type)
            VALUES (reply_to_owner_id, new.user_id, new.post_id, new.id, 'comment_reply');
        END IF;
    END IF;

    RETURN new;
END;
$$;
