--
-- PostgreSQL database dump
--
-- Baseline generated from the linked remote Supabase project on 2026-02-23.
-- This migration is intended to be marked as applied on the current project,
-- and used as the repo source-of-truth snapshot moving forward.

-- Dumped from database version 17.6
-- Dumped by pg_dump version 18.2

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: public; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA IF NOT EXISTS public;


--
-- Name: SCHEMA public; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON SCHEMA public IS 'standard public schema';


--
-- Name: post_type; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.post_type AS ENUM (
    'text',
    'image',
    'video',
    'news',
    'review',
    'trailer'
);


--
-- Name: create_post_metrics_row(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.create_post_metrics_row() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
  insert into post_metrics (post_id)
  values (new.id);
  return new;
end;
$$;


--
-- Name: recalc_hot_score(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.recalc_hot_score() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
  update post_metrics
  set hot_score =
    (ln(reaction_count + 1) * 0.6)
    + (velocity_score * 1.2)
    + exp(-extract(epoch from (now() - (select created_at from posts where id = post_id))) / 86400)
  where post_id = new.post_id;

  return new;
end;
$$;


--
-- Name: update_post_metrics_on_comment(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_post_metrics_on_comment() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
  update post_metrics
  set comment_count = comment_count + 1
  where post_id = new.post_id;

  return new;
end;
$$;


--
-- Name: update_post_metrics_on_reaction(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_post_metrics_on_reaction() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
  update post_metrics
  set
    reaction_count = reaction_count + 1,
    last_reaction_at = now(),
    velocity_score = velocity_score + 1
  where post_id = new.post_id;

  return new;
end;
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: comments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.comments (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    post_id uuid,
    user_id uuid,
    parent_comment_id uuid,
    body text NOT NULL,
    created_at timestamp without time zone DEFAULT now()
);


--
-- Name: games; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.games (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    title text NOT NULL,
    cover_image_url text,
    release_date date,
    genre text,
    created_at timestamp without time zone DEFAULT now()
);


--
-- Name: post_metrics; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.post_metrics (
    post_id uuid NOT NULL,
    reaction_count integer DEFAULT 0,
    comment_count integer DEFAULT 0,
    last_reaction_at timestamp without time zone,
    velocity_score double precision DEFAULT 0,
    hot_score double precision DEFAULT 0
);


--
-- Name: posts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.posts (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    author_id uuid,
    game_id uuid,
    type public.post_type NOT NULL,
    title text,
    body text,
    media_url text,
    thumbnail_url text,
    is_system_generated boolean DEFAULT false,
    created_at timestamp without time zone DEFAULT now()
);


--
-- Name: hot_feed_view; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.hot_feed_view AS
 SELECT p.id,
    p.author_id,
    p.game_id,
    p.type,
    p.title,
    p.body,
    p.media_url,
    p.thumbnail_url,
    p.is_system_generated,
    p.created_at,
    m.reaction_count,
    m.comment_count,
    m.hot_score
   FROM (public.posts p
     JOIN public.post_metrics m ON ((p.id = m.post_id)))
  ORDER BY m.hot_score DESC;


--
-- Name: reaction_types; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.reaction_types (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    slug text NOT NULL,
    display_name text,
    emoji text NOT NULL,
    created_at timestamp without time zone DEFAULT now()
);


--
-- Name: reactions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.reactions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    post_id uuid,
    user_id uuid,
    reaction_type_id uuid,
    created_at timestamp without time zone DEFAULT now()
);


--
-- Name: user_followed_games; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_followed_games (
    user_id uuid NOT NULL,
    game_id uuid NOT NULL,
    created_at timestamp without time zone DEFAULT now()
);


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users (
    id uuid NOT NULL,
    username text NOT NULL,
    avatar_url text,
    created_at timestamp without time zone DEFAULT now(),
    onboarding_complete boolean DEFAULT false,
    display_name text,
    email text
);


--
-- Name: comments comments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.comments
    ADD CONSTRAINT comments_pkey PRIMARY KEY (id);


--
-- Name: games games_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.games
    ADD CONSTRAINT games_pkey PRIMARY KEY (id);


--
-- Name: post_metrics post_metrics_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_metrics
    ADD CONSTRAINT post_metrics_pkey PRIMARY KEY (post_id);


--
-- Name: posts posts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.posts
    ADD CONSTRAINT posts_pkey PRIMARY KEY (id);


--
-- Name: reaction_types reaction_types_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reaction_types
    ADD CONSTRAINT reaction_types_pkey PRIMARY KEY (id);


--
-- Name: reaction_types reaction_types_slug_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reaction_types
    ADD CONSTRAINT reaction_types_slug_key UNIQUE (slug);


--
-- Name: reactions reactions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reactions
    ADD CONSTRAINT reactions_pkey PRIMARY KEY (id);


--
-- Name: reactions reactions_post_id_user_id_reaction_type_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reactions
    ADD CONSTRAINT reactions_post_id_user_id_reaction_type_id_key UNIQUE (post_id, user_id, reaction_type_id);


--
-- Name: user_followed_games user_followed_games_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_followed_games
    ADD CONSTRAINT user_followed_games_pkey PRIMARY KEY (user_id, game_id);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: users users_username_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_username_key UNIQUE (username);


--
-- Name: comments comment_insert_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER comment_insert_trigger AFTER INSERT ON public.comments FOR EACH ROW EXECUTE FUNCTION public.update_post_metrics_on_comment();


--
-- Name: post_metrics hot_score_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER hot_score_trigger AFTER UPDATE ON public.post_metrics FOR EACH ROW EXECUTE FUNCTION public.recalc_hot_score();


--
-- Name: posts post_insert_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER post_insert_trigger AFTER INSERT ON public.posts FOR EACH ROW EXECUTE FUNCTION public.create_post_metrics_row();


--
-- Name: reactions reaction_insert_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER reaction_insert_trigger AFTER INSERT ON public.reactions FOR EACH ROW EXECUTE FUNCTION public.update_post_metrics_on_reaction();


--
-- Name: comments comments_parent_comment_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.comments
    ADD CONSTRAINT comments_parent_comment_id_fkey FOREIGN KEY (parent_comment_id) REFERENCES public.comments(id) ON DELETE CASCADE;


--
-- Name: comments comments_post_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.comments
    ADD CONSTRAINT comments_post_id_fkey FOREIGN KEY (post_id) REFERENCES public.posts(id) ON DELETE CASCADE;


--
-- Name: comments comments_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.comments
    ADD CONSTRAINT comments_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: post_metrics post_metrics_post_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_metrics
    ADD CONSTRAINT post_metrics_post_id_fkey FOREIGN KEY (post_id) REFERENCES public.posts(id) ON DELETE CASCADE;


--
-- Name: posts posts_author_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.posts
    ADD CONSTRAINT posts_author_id_fkey FOREIGN KEY (author_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: posts posts_game_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.posts
    ADD CONSTRAINT posts_game_id_fkey FOREIGN KEY (game_id) REFERENCES public.games(id) ON DELETE SET NULL;


--
-- Name: reactions reactions_post_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reactions
    ADD CONSTRAINT reactions_post_id_fkey FOREIGN KEY (post_id) REFERENCES public.posts(id) ON DELETE CASCADE;


--
-- Name: reactions reactions_reaction_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reactions
    ADD CONSTRAINT reactions_reaction_type_id_fkey FOREIGN KEY (reaction_type_id) REFERENCES public.reaction_types(id);


--
-- Name: reactions reactions_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reactions
    ADD CONSTRAINT reactions_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: user_followed_games user_followed_games_game_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_followed_games
    ADD CONSTRAINT user_followed_games_game_id_fkey FOREIGN KEY (game_id) REFERENCES public.games(id) ON DELETE CASCADE;


--
-- Name: user_followed_games user_followed_games_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_followed_games
    ADD CONSTRAINT user_followed_games_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: users users_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: comments Comments are viewable by everyone; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Comments are viewable by everyone" ON public.comments FOR SELECT USING (true);


--
-- Name: posts Posts are viewable by everyone; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Posts are viewable by everyone" ON public.posts FOR SELECT USING (true);


--
-- Name: reactions Reactions are viewable by everyone; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Reactions are viewable by everyone" ON public.reactions FOR SELECT USING (true);


--
-- Name: users Users are viewable by everyone; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users are viewable by everyone" ON public.users FOR SELECT USING (true);


--
-- Name: comments Users can comment; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can comment" ON public.comments FOR INSERT WITH CHECK ((auth.uid() = user_id));


--
-- Name: user_followed_games Users can follow games; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can follow games" ON public.user_followed_games FOR INSERT WITH CHECK ((auth.uid() = user_id));


--
-- Name: users Users can insert own profile; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can insert own profile" ON public.users FOR INSERT WITH CHECK ((auth.uid() = id));


--
-- Name: posts Users can insert posts; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can insert posts" ON public.posts FOR INSERT WITH CHECK ((auth.uid() = author_id));


--
-- Name: reactions Users can react; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can react" ON public.reactions FOR INSERT WITH CHECK ((auth.uid() = user_id));


--
-- Name: comments; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.comments ENABLE ROW LEVEL SECURITY;

--
-- Name: posts; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.posts ENABLE ROW LEVEL SECURITY;

--
-- Name: reactions; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.reactions ENABLE ROW LEVEL SECURITY;

--
-- Name: user_followed_games; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.user_followed_games ENABLE ROW LEVEL SECURITY;

--
-- Name: users; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

--
-- Name: users users_rw_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY users_rw_own ON public.users TO authenticated USING ((id = auth.uid())) WITH CHECK ((id = auth.uid()));


--
-- PostgreSQL database dump complete
--
