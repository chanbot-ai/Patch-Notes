-- ============================================================
-- Steam Integration Tables + Community Health RPC
-- Adds persistent Steam profile/game storage and community health
-- ============================================================

-- 1. Add steam_app_id to games table for catalog matching
ALTER TABLE public.games
  ADD COLUMN IF NOT EXISTS steam_app_id integer;

CREATE UNIQUE INDEX IF NOT EXISTS idx_games_steam_app_id
  ON public.games (steam_app_id)
  WHERE steam_app_id IS NOT NULL;

-- 2. User Steam Profiles table
CREATE TABLE IF NOT EXISTS public.user_steam_profiles (
  user_id uuid PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
  steam_id text NOT NULL,
  persona_name text,
  avatar_url text,
  profile_url text,
  last_synced_at timestamptz DEFAULT now(),
  created_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_user_steam_profiles_steam_id
  ON public.user_steam_profiles (steam_id);

ALTER TABLE public.user_steam_profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read own Steam profile"
  ON public.user_steam_profiles FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own Steam profile"
  ON public.user_steam_profiles FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own Steam profile"
  ON public.user_steam_profiles FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Service role full access to steam profiles"
  ON public.user_steam_profiles FOR ALL
  USING (auth.role() = 'service_role');

-- 3. User Steam Games table
CREATE TABLE IF NOT EXISTS public.user_steam_games (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  steam_app_id integer NOT NULL,
  name text NOT NULL,
  playtime_forever_minutes integer DEFAULT 0,
  playtime_2weeks_minutes integer DEFAULT 0,
  last_played_at timestamptz,
  cover_image_url text,
  game_id uuid REFERENCES public.games(id) ON DELETE SET NULL,
  synced_at timestamptz DEFAULT now(),
  UNIQUE(user_id, steam_app_id)
);

CREATE INDEX IF NOT EXISTS idx_user_steam_games_user
  ON public.user_steam_games (user_id);

CREATE INDEX IF NOT EXISTS idx_user_steam_games_game
  ON public.user_steam_games (game_id)
  WHERE game_id IS NOT NULL;

ALTER TABLE public.user_steam_games ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read own Steam games"
  ON public.user_steam_games FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can manage own Steam games"
  ON public.user_steam_games FOR ALL
  USING (auth.uid() = user_id);

CREATE POLICY "Service role full access to steam games"
  ON public.user_steam_games FOR ALL
  USING (auth.role() = 'service_role');

-- 4. RPC: fetch_my_steam_owned_games
CREATE OR REPLACE FUNCTION public.fetch_my_steam_owned_games(
  p_limit integer DEFAULT 200
)
RETURNS TABLE (
  steam_app_id integer,
  name text,
  playtime_forever_minutes integer,
  playtime_2weeks_minutes integer,
  last_played_at timestamptz,
  cover_image_url text,
  game_id uuid,
  game_title text
)
LANGUAGE sql
STABLE
SECURITY INVOKER
AS $$
  SELECT
    sg.steam_app_id,
    sg.name,
    sg.playtime_forever_minutes,
    sg.playtime_2weeks_minutes,
    sg.last_played_at,
    sg.cover_image_url,
    sg.game_id,
    g.title AS game_title
  FROM public.user_steam_games sg
  LEFT JOIN public.games g ON g.id = sg.game_id
  WHERE sg.user_id = auth.uid()
  ORDER BY sg.playtime_forever_minutes DESC
  LIMIT p_limit;
$$;

GRANT EXECUTE ON FUNCTION public.fetch_my_steam_owned_games(integer) TO authenticated;

-- 5. RPC: fetch_game_community_health
CREATE OR REPLACE FUNCTION public.fetch_game_community_health(
  p_game_id uuid,
  p_lookback_interval interval DEFAULT '7 days'::interval
)
RETURNS TABLE (
  game_id uuid,
  game_title text,
  total_posts bigint,
  recent_posts bigint,
  total_comments bigint,
  unique_authors bigint,
  is_quiet boolean,
  quiet_message text
)
LANGUAGE sql
STABLE
SECURITY INVOKER
AS $$
  WITH stats AS (
    SELECT
      count(*) AS total_posts,
      count(*) FILTER (WHERE p.created_at >= now() - p_lookback_interval) AS recent_posts,
      count(DISTINCT p.author_id) AS unique_authors
    FROM public.posts p
    WHERE coalesce(p.game_id, public.game_id_from_primary_badge_key(p.primary_badge_key)) = p_game_id
  ),
  comment_stats AS (
    SELECT count(*) AS total_comments
    FROM public.comments c
    JOIN public.posts p ON p.id = c.post_id
    WHERE coalesce(p.game_id, public.game_id_from_primary_badge_key(p.primary_badge_key)) = p_game_id
  )
  SELECT
    p_game_id AS game_id,
    g.title AS game_title,
    s.total_posts,
    s.recent_posts,
    cs.total_comments,
    s.unique_authors,
    (s.recent_posts = 0) AS is_quiet,
    CASE
      WHEN s.total_posts = 0 THEN 'This community is brand new — be the first to start a conversation!'
      WHEN s.recent_posts = 0 THEN 'It''s been quiet here lately. Check back soon for fresh content.'
      ELSE NULL
    END AS quiet_message
  FROM stats s
  CROSS JOIN comment_stats cs
  LEFT JOIN public.games g ON g.id = p_game_id;
$$;

GRANT EXECUTE ON FUNCTION public.fetch_game_community_health(uuid, interval) TO anon;
GRANT EXECUTE ON FUNCTION public.fetch_game_community_health(uuid, interval) TO authenticated;
