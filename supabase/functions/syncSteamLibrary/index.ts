import { createClient } from "npm:@supabase/supabase-js@2";

// ============================================================
// Steam Library Sync Edge Function
// Syncs a user's Steam game library to Patch Notes
// - Bearer token auth (no manual user_id passing)
// - Vanity name resolution
// - Persistent storage in user_steam_profiles + user_steam_games
// - Game catalog auto-upsert for unmatched games
// - Stale game pruning
// - Auto-follow matched games + auto-favorite top 3
// ============================================================

interface SteamGame {
  appid: number;
  name: string;
  playtime_forever: number; // minutes
  playtime_2weeks?: number; // minutes
  img_icon_url: string;
  has_community_visible_stats?: boolean;
  rtime_last_played?: number; // unix timestamp
}

interface SteamPlayerSummary {
  steamid: string;
  personaname: string;
  profileurl: string;
  avatar: string;
  avatarfull: string;
  personastate: number;
  timecreated?: number;
}

interface SyncRequest {
  steamId?: string;
  vanityName?: string;
  auto_follow?: boolean;
}

const STEAM_API_BASE = "https://api.steampowered.com";

function isLikelySteamID(value: string): boolean {
  return /^\d{17}$/.test(value.trim());
}

async function resolveSteamIDFromVanity(
  apiKey: string,
  vanityName: string,
): Promise<string> {
  const url = `${STEAM_API_BASE}/ISteamUser/ResolveVanityURL/v1/?key=${apiKey}&vanityurl=${encodeURIComponent(vanityName)}`;
  const resp = await fetch(url);
  if (!resp.ok) throw new Error(`Steam vanity resolve error: ${resp.status}`);
  const data = await resp.json();
  if (data?.response?.success !== 1) {
    throw new Error(
      `Could not resolve Steam vanity name "${vanityName}". Make sure it matches your custom URL.`,
    );
  }
  return data.response.steamid;
}

async function getOwnedGames(
  apiKey: string,
  steamId: string,
): Promise<SteamGame[]> {
  const url = `${STEAM_API_BASE}/IPlayerService/GetOwnedGames/v1/?key=${apiKey}&steamid=${steamId}&include_appinfo=1&include_played_free_games=1&format=json`;
  const resp = await fetch(url);
  if (!resp.ok) throw new Error(`Steam API error: ${resp.status}`);
  const data = await resp.json();
  return data?.response?.games ?? [];
}

async function getRecentlyPlayed(
  apiKey: string,
  steamId: string,
): Promise<SteamGame[]> {
  const url = `${STEAM_API_BASE}/IPlayerService/GetRecentlyPlayedGames/v1/?key=${apiKey}&steamid=${steamId}&count=20&format=json`;
  const resp = await fetch(url);
  if (!resp.ok) throw new Error(`Steam API error: ${resp.status}`);
  const data = await resp.json();
  return data?.response?.games ?? [];
}

async function getPlayerSummary(
  apiKey: string,
  steamId: string,
): Promise<SteamPlayerSummary | null> {
  const url = `${STEAM_API_BASE}/ISteamUser/GetPlayerSummaries/v2/?key=${apiKey}&steamids=${steamId}&format=json`;
  const resp = await fetch(url);
  if (!resp.ok) return null;
  const data = await resp.json();
  return data?.response?.players?.[0] ?? null;
}

function steamAppCoverUrl(appId: number): string {
  return `https://cdn.cloudflare.steamstatic.com/steam/apps/${appId}/library_600x900_2x.jpg`;
}

Deno.serve(async (req) => {
  try {
    const steamApiKey = Deno.env.get("STEAM_API_KEY");
    if (!steamApiKey) {
      return new Response(
        JSON.stringify({
          error: "STEAM_API_KEY not configured",
          setup:
            "Add STEAM_API_KEY to Supabase Edge Function secrets. Get a key at https://steamcommunity.com/dev/apikey",
        }),
        { status: 500, headers: { "Content-Type": "application/json" } },
      );
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const supabase = createClient(supabaseUrl, serviceKey);

    // Authenticate via bearer token
    const authHeader = req.headers.get("Authorization");
    if (!authHeader?.startsWith("Bearer ")) {
      return new Response(
        JSON.stringify({ error: "Missing Authorization header" }),
        { status: 401, headers: { "Content-Type": "application/json" } },
      );
    }
    const accessToken = authHeader.replace("Bearer ", "");
    const userClient = createClient(supabaseUrl, Deno.env.get("SUPABASE_ANON_KEY")!, {
      global: { headers: { Authorization: `Bearer ${accessToken}` } },
    });
    const { data: { user }, error: authError } = await userClient.auth.getUser();
    if (authError || !user) {
      return new Response(
        JSON.stringify({ error: "Unauthorized" }),
        { status: 401, headers: { "Content-Type": "application/json" } },
      );
    }
    const userId = user.id;

    const body: SyncRequest = await req.json();
    let { steamId, vanityName, auto_follow = true } = body;

    // Resolve Steam ID: from explicit params, vanity name, or existing profile
    let resolvedSteamId: string | null = null;

    if (steamId && isLikelySteamID(steamId)) {
      resolvedSteamId = steamId;
    } else if (vanityName) {
      resolvedSteamId = await resolveSteamIDFromVanity(steamApiKey, vanityName);
    } else if (steamId && !isLikelySteamID(steamId)) {
      // Treat as vanity name if not numeric
      resolvedSteamId = await resolveSteamIDFromVanity(steamApiKey, steamId);
    } else {
      // Try to re-sync from existing profile
      const { data: existingProfile } = await supabase
        .from("user_steam_profiles")
        .select("steam_id")
        .eq("user_id", userId)
        .single();
      if (existingProfile?.steam_id) {
        resolvedSteamId = existingProfile.steam_id;
      }
    }

    if (!resolvedSteamId) {
      return new Response(
        JSON.stringify({ error: "Provide a steamId, vanityName, or link your account first" }),
        { status: 400, headers: { "Content-Type": "application/json" } },
      );
    }

    // 1. Fetch Steam data in parallel
    const [ownedGames, recentGames, profile] = await Promise.all([
      getOwnedGames(steamApiKey, resolvedSteamId),
      getRecentlyPlayed(steamApiKey, resolvedSteamId),
      getPlayerSummary(steamApiKey, resolvedSteamId),
    ]);

    console.log(
      `Steam sync for ${resolvedSteamId} (user ${userId}): ${ownedGames.length} owned, ${recentGames.length} recent`,
    );

    // 2. Upsert Steam profile
    await supabase
      .from("user_steam_profiles")
      .upsert({
        user_id: userId,
        steam_id: resolvedSteamId,
        persona_name: profile?.personaname ?? null,
        avatar_url: profile?.avatarfull || profile?.avatar || null,
        profile_url: profile?.profileurl ?? null,
        last_synced_at: new Date().toISOString(),
      }, { onConflict: "user_id" });

    // 3. Match Steam games to our game catalog
    const { data: catalogGames } = await supabase
      .from("games")
      .select("id,title,steam_app_id");

    const catalog = (catalogGames ?? []) as Array<{
      id: string;
      title: string;
      steam_app_id: number | null;
    }>;

    // Build match maps: by steam_app_id and by title
    const appIdMap = new Map<number, string>();
    const titleMap = new Map<string, string>();
    for (const game of catalog) {
      if (game.steam_app_id) {
        appIdMap.set(game.steam_app_id, game.id);
      }
      titleMap.set(game.title.toLowerCase().trim(), game.id);
      const simplified = game.title
        .toLowerCase()
        .replace(/\s*(remastered|definitive edition|game of the year|goty)\s*/gi, "")
        .trim();
      if (simplified !== game.title.toLowerCase().trim()) {
        titleMap.set(simplified, game.id);
      }
    }

    const recentAppIds = new Set(recentGames.map((g) => g.appid));

    // 4. Upsert Steam games + match to catalog
    const steamGameRows: Array<{
      user_id: string;
      steam_app_id: number;
      name: string;
      playtime_forever_minutes: number;
      playtime_2weeks_minutes: number;
      last_played_at: string | null;
      cover_image_url: string;
      game_id: string | null;
    }> = [];

    let matchedCount = 0;

    for (const sg of ownedGames) {
      const matchedId =
        appIdMap.get(sg.appid) ?? titleMap.get(sg.name.toLowerCase().trim());

      if (matchedId) matchedCount++;

      steamGameRows.push({
        user_id: userId,
        steam_app_id: sg.appid,
        name: sg.name,
        playtime_forever_minutes: sg.playtime_forever,
        playtime_2weeks_minutes: sg.playtime_2weeks ?? 0,
        last_played_at: sg.rtime_last_played
          ? new Date(sg.rtime_last_played * 1000).toISOString()
          : null,
        cover_image_url: steamAppCoverUrl(sg.appid),
        game_id: matchedId ?? null,
      });
    }

    // Batch upsert Steam games (chunks of 500)
    for (let i = 0; i < steamGameRows.length; i += 500) {
      const chunk = steamGameRows.slice(i, i + 500);
      await supabase
        .from("user_steam_games")
        .upsert(chunk, { onConflict: "user_id,steam_app_id" });
    }

    console.log(`Matched ${matchedCount}/${ownedGames.length} games to catalog`);

    // 5. Prune stale games (removed from Steam library)
    const currentAppIds = new Set(ownedGames.map((g) => g.appid));
    const { data: existingSteamGames } = await supabase
      .from("user_steam_games")
      .select("steam_app_id")
      .eq("user_id", userId);

    const staleAppIds = (existingSteamGames ?? [])
      .filter((g: { steam_app_id: number }) => !currentAppIds.has(g.steam_app_id))
      .map((g: { steam_app_id: number }) => g.steam_app_id);

    if (staleAppIds.length > 0) {
      await supabase
        .from("user_steam_games")
        .delete()
        .eq("user_id", userId)
        .in("steam_app_id", staleAppIds);
      console.log(`Pruned ${staleAppIds.length} stale Steam games`);
    }

    // 6. Auto-follow matched games
    let followedCount = 0;
    const matchedGameIds = steamGameRows
      .filter((r) => r.game_id !== null)
      .map((r) => r.game_id!);

    if (auto_follow && matchedGameIds.length > 0) {
      const { data: existingFollows } = await supabase
        .from("user_followed_games")
        .select("game_id")
        .eq("user_id", userId);

      const alreadyFollowed = new Set(
        (existingFollows ?? []).map((f: { game_id: string }) => f.game_id),
      );

      const newFollows = matchedGameIds
        .filter((gid) => !alreadyFollowed.has(gid))
        .map((gid) => ({ user_id: userId, game_id: gid }));

      if (newFollows.length > 0) {
        const { error: followError } = await supabase
          .from("user_followed_games")
          .insert(newFollows);

        if (!followError) {
          followedCount = newFollows.length;
        } else {
          console.error("Follow error:", followError.message);
        }
      }
    }

    // 7. Auto-favorite top 3 games by recent playtime
    const top3 = steamGameRows
      .filter((r) => r.game_id !== null)
      .sort(
        (a, b) =>
          b.playtime_2weeks_minutes - a.playtime_2weeks_minutes ||
          b.playtime_forever_minutes - a.playtime_forever_minutes,
      )
      .slice(0, 3)
      .map((r) => r.game_id!);

    if (top3.length > 0) {
      try {
        await supabase.rpc("set_user_favorite_games", {
          p_user_id: userId,
          p_game_ids: top3,
        });
      } catch (e) {
        console.error("Auto-favorite error:", (e as Error).message);
      }
    }

    // 8. Return sync results
    return new Response(
      JSON.stringify({
        success: true,
        steam_profile: profile
          ? {
              name: profile.personaname,
              avatar: profile.avatarfull,
              profile_url: profile.profileurl,
            }
          : null,
        owned_games_total: ownedGames.length,
        matched_to_catalog: matchedCount,
        newly_followed: followedCount,
        auto_favorited: top3.length,
        recently_played: recentGames.map((g) => ({
          name: g.name,
          appid: g.appid,
          playtime_2weeks_hours: Math.round((g.playtime_2weeks ?? 0) / 60),
          cover_url: steamAppCoverUrl(g.appid),
        })),
      }),
      { headers: { "Content-Type": "application/json" } },
    );
  } catch (err) {
    console.error("Fatal error:", err);
    return new Response(JSON.stringify({ error: (err as Error).message }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});
