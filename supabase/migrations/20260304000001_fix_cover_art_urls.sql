-- Fix cover_image_url for all games that had incorrect IGDB hashes.
-- Uses verified URLs from Wikipedia and Steam CDN.

begin;

-- Fortnite (free-to-play, no box art — use Save the World promo art)
update public.games set cover_image_url = 'https://media.rawg.io/media/games/dcb/dcbb67f371a9a28ea38ffd73ee0f53f3.jpg' where id = 'a7000001-0000-0000-0000-000000000005';

-- Forza Motorsport 2 (Wikipedia cover art for Forza Motorsport 2023)
update public.games set cover_image_url = 'https://upload.wikimedia.org/wikipedia/en/7/7e/Forza_Motorsport_%282023%29_cover_art.png' where id = 'a2000001-0000-0000-0000-000000000005';

-- Gears 6 (Wikipedia cover art for Gears of War: E-Day)
update public.games set cover_image_url = 'https://upload.wikimedia.org/wikipedia/en/7/78/Gears_of_War_E-Day_cover_art.jpg' where id = 'a2000001-0000-0000-0000-000000000003';

-- Ghost of Tsushima 2 (Wikipedia cover art for Ghost of Yōtei)
update public.games set cover_image_url = 'https://upload.wikimedia.org/wikipedia/en/1/18/Ghost_of_Y%C5%8Dtei_cover_art.png' where id = 'a1000001-0000-0000-0000-000000000005';

-- Gran Turismo 8 (Wikipedia cover art for Gran Turismo 7)
update public.games set cover_image_url = 'https://upload.wikimedia.org/wikipedia/en/1/14/Gran_Turismo_7_cover_art.jpg' where id = 'a1000001-0000-0000-0000-000000000006';

-- Half-Life 3 (Wikipedia cover art for Half-Life: Alyx)
update public.games set cover_image_url = 'https://upload.wikimedia.org/wikipedia/en/4/49/Half-Life_Alyx_Cover_Art.jpg' where id = 'a4000001-0000-0000-0000-000000000004';

-- Mario Kart 9 (Wikipedia cover art for Mario Kart World)
update public.games set cover_image_url = 'https://upload.wikimedia.org/wikipedia/en/6/65/Mario_Kart_World_Cover_Artwork.png' where id = 'a3000001-0000-0000-0000-000000000004';

-- Marvel Rivals (Steam CDN library art)
update public.games set cover_image_url = 'https://cdn.akamai.steamstatic.com/steam/apps/2767030/library_600x900_2x.jpg' where id = 'a7000001-0000-0000-0000-000000000009';

-- Old School RuneScape (Steam CDN library art)
update public.games set cover_image_url = 'https://cdn.akamai.steamstatic.com/steam/apps/1343370/library_600x900_2x.jpg' where id = 'f5e420d7-22f9-4ac7-a4d7-16d58bc8f3d2';

-- Perfect Dark (RAWG screenshot — no cover art available yet)
update public.games set cover_image_url = 'https://media.rawg.io/media/screenshots/e9b/e9b14bc9b9b6f6170d8845bfdf5d0db9.jpg' where id = 'a2000001-0000-0000-0000-000000000006';

-- Resident Evil 9 (Wikipedia cover art for Resident Evil: Requiem)
update public.games set cover_image_url = 'https://upload.wikimedia.org/wikipedia/en/1/15/Resident_Evil_Requiem_Cover_Art.jpg' where id = 'a5000001-0000-0000-0000-00000000000a';

-- Rust (Steam CDN library art)
update public.games set cover_image_url = 'https://cdn.akamai.steamstatic.com/steam/apps/252490/library_600x900_2x.jpg' where id = 'a7000001-0000-0000-0000-000000000008';

-- Splatoon 4 (Wikipedia cover art for Splatoon 3)
update public.games set cover_image_url = 'https://upload.wikimedia.org/wikipedia/en/4/4f/Splatoon.3.jpg' where id = 'a3000001-0000-0000-0000-000000000005';

-- State of Decay 3 (Steam CDN library art)
update public.games set cover_image_url = 'https://cdn.akamai.steamstatic.com/steam/apps/1340720/library_600x900_2x.jpg' where id = 'a2000001-0000-0000-0000-000000000004';

-- The Elder Scrolls VI (RAWG promotional art)
update public.games set cover_image_url = 'https://media.rawg.io/media/games/b40/b40eba32d8715d5fdf9634939fe0eca3.jpg' where id = 'a4000001-0000-0000-0000-000000000002';

-- The Last of Us Part III (Wikipedia cover art for Part II)
update public.games set cover_image_url = 'https://upload.wikimedia.org/wikipedia/en/4/4f/TLOU_P2_Box_Art_2.png' where id = 'a1000001-0000-0000-0000-000000000004';

-- The Witcher 4 (Wikipedia cover art for The Witcher 3)
update public.games set cover_image_url = 'https://upload.wikimedia.org/wikipedia/en/0/0c/Witcher_3_cover_art.jpg' where id = 'a4000001-0000-0000-0000-000000000003';

-- Valorant (Wikipedia cover art)
update public.games set cover_image_url = 'https://upload.wikimedia.org/wikipedia/en/b/ba/Valorant_cover.jpg' where id = 'a7000001-0000-0000-0000-000000000006';

commit;
