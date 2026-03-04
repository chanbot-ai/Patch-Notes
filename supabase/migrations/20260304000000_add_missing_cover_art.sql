-- Add cover_image_url for all games that are currently missing one.
-- Uses Wikipedia/IGDB cover art where available.

begin;

update public.games set cover_image_url = 'https://images.igdb.com/igdb/image/upload/t_cover_big/co1rgi.webp' where id = 'a7000001-0000-0000-0000-000000000005'; -- Fortnite
update public.games set cover_image_url = 'https://images.igdb.com/igdb/image/upload/t_cover_big/co7kha.webp' where id = 'a2000001-0000-0000-0000-000000000005'; -- Forza Motorsport 2
update public.games set cover_image_url = 'https://images.igdb.com/igdb/image/upload/t_cover_big/co5qk8.webp' where id = 'a2000001-0000-0000-0000-000000000003'; -- Gears 6
update public.games set cover_image_url = 'https://upload.wikimedia.org/wikipedia/en/b/b4/Ghost_of_Tsushima.jpg' where id = 'a1000001-0000-0000-0000-000000000005'; -- Ghost of Tsushima 2
update public.games set cover_image_url = 'https://images.igdb.com/igdb/image/upload/t_cover_big/co2g84.webp' where id = 'a1000001-0000-0000-0000-000000000006'; -- Gran Turismo 8
update public.games set cover_image_url = 'https://images.igdb.com/igdb/image/upload/t_cover_big/co8b3b.webp' where id = 'a4000001-0000-0000-0000-000000000004'; -- Half-Life 3
update public.games set cover_image_url = 'https://images.igdb.com/igdb/image/upload/t_cover_big/co7wgl.webp' where id = 'a3000001-0000-0000-0000-000000000004'; -- Mario Kart 9
update public.games set cover_image_url = 'https://images.igdb.com/igdb/image/upload/t_cover_big/co8dql.webp' where id = 'a7000001-0000-0000-0000-000000000009'; -- Marvel Rivals
update public.games set cover_image_url = 'https://images.igdb.com/igdb/image/upload/t_cover_big/co2sxb.webp' where id = 'f5e420d7-22f9-4ac7-a4d7-16d58bc8f3d2'; -- Old School RuneScape
update public.games set cover_image_url = 'https://images.igdb.com/igdb/image/upload/t_cover_big/co5bo5.webp' where id = 'a2000001-0000-0000-0000-000000000006'; -- Perfect Dark
update public.games set cover_image_url = 'https://upload.wikimedia.org/wikipedia/en/2/21/Resident_Evil_Village_cover_art.png' where id = 'a5000001-0000-0000-0000-00000000000a'; -- Resident Evil 9
update public.games set cover_image_url = 'https://images.igdb.com/igdb/image/upload/t_cover_big/co6fz0.webp' where id = 'a7000001-0000-0000-0000-000000000008'; -- Rust
update public.games set cover_image_url = 'https://images.igdb.com/igdb/image/upload/t_cover_big/co1xhx.webp' where id = 'a3000001-0000-0000-0000-000000000005'; -- Splatoon 4
update public.games set cover_image_url = 'https://images.igdb.com/igdb/image/upload/t_cover_big/co5s6u.webp' where id = 'a2000001-0000-0000-0000-000000000004'; -- State of Decay 3
update public.games set cover_image_url = 'https://images.igdb.com/igdb/image/upload/t_cover_big/co4yav.webp' where id = 'a4000001-0000-0000-0000-000000000002'; -- The Elder Scrolls VI
update public.games set cover_image_url = 'https://upload.wikimedia.org/wikipedia/en/4/46/Video_Game_Cover_-_The_Last_of_Us.jpg' where id = 'a1000001-0000-0000-0000-000000000004'; -- The Last of Us Part III
update public.games set cover_image_url = 'https://images.igdb.com/igdb/image/upload/t_cover_big/co8bkm.webp' where id = 'a4000001-0000-0000-0000-000000000003'; -- The Witcher 4
update public.games set cover_image_url = 'https://images.igdb.com/igdb/image/upload/t_cover_big/co2mvt.webp' where id = 'a7000001-0000-0000-0000-000000000006'; -- Valorant

commit;
