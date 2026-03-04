import { createClient } from "npm:@supabase/supabase-js@2";

// ============================================================
// Steam Library Sync Edge Function
// Syncs a user's Steam game library to Patch Notes
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
  steam_id: string; // 64-bit Steam ID
  user_id: string; // Supabase user UUID
  auto_follow?: boolean; // Whether to auto-follow games found in catalog
}

const STEAM_API_BASE = "https://api.steampowered.com";

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
  return `https://cdn.akamai.steamstatic.com/steam/apps/${appId}/library_600x900_2x.jpg`;
}

function steamAppHeaderUrl(appId: number): string {
  return `https://cdn.akamai.steamstatic.com/steam/apps/${appId}/header.jpg`;
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

    const body: SyncRequest = await req.json();
    const { steam_id, user_id, auto_follow = true } = body;

    if (!steam_id || !user_id) {
      return new Response(
        JSON.stringify({ error: "steam_id and user_id are required" }),
        { status: 400, headers: { "Content-Type": "application/json" } },
      );
    }

    // 1. Fetch Steam data in parallel
    const [ownedGames, recentGames, profile] = await Promise.all([
      getOwnedGames(steamApiKey, steam_id),
      getRecentlyPlayed(steamApiKey, steam_id),
      getPlayerSummary(steamApiKey, steam_id),
    ]);

    console.log(
      `Steam sync for ${steam_id}: ${ownedGames.length} owned, ${recentGames.length} recent`,
    );

    // 2. Store Steam profile link on user
    if (profile) {
      await supabase
        .from("users")
        .update({
          avatar_url: profile.avatarfull || profile.avatar || undefined,
        })
        .eq("id", user_id);
    }

    // 3. Match Steam games to our game catalog
    // Fetch all games from our catalog
    const { data: catalogGames } = await supabase
      .from("games")
      .select("id,title");

    const catalog = (catalogGames ?? []) as Array<{
      id: string;
      title: string;
    }>;

    // Build a fuzzy match map (lowercase title → game id)
    const titleMap = new Map<string, string>();
    for (const game of catalog) {
      titleMap.set(game.title.toLowerCase().trim(), game.id);
      // Also try without common suffixes
      const simplified = game.title
        .toLowerCase()
        .replace(/\s*(remastered|definitive edition|game of the year|goty)\s*/gi, "")
        .trim();
      if (simplified !== game.title.toLowerCase().trim()) {
        titleMap.set(simplified, game.id);
      }
    }

    const matchedGames: Array<{
      steam_appid: number;
      name: string;
      game_id: string;
      playtime_hours: number;
      recently_played: boolean;
    }> = [];

    const recentAppIds = new Set(recentGames.map((g) => g.appid));

    for (const steamGame of ownedGames) {
      const matchedId = titleMap.get(steamGame.name.toLowerCase().trim());
      if (matchedId) {
        matchedGames.push({
          steam_appid: steamGame.appid,
          name: steamGame.name,
          game_id: matchedId,
          playtime_hours: Math.round(steamGame.playtime_forever / 60),
          recently_played: recentAppIds.has(steamGame.appid),
        });
      }
    }

    console.log(
      `Matched ${matchedGames.length}/${ownedGames.length} games to catalog`,
    );

    // 4. Auto-follow matched games
    let followedCount = 0;
    if (auto_follow && matchedGames.length > 0) {
      // Get already-followed game IDs
      const { data: existingFollows } = await supabase
        .from("user_game_follows")
        .select("game_id")
        .eq("user_id", user_id);

      const alreadyFollowed = new Set(
        (existingFollows ?? []).map((f: { game_id: string }) => f.game_id),
      );

      const newFollows = matchedGames
        .filter((m) => !alreadyFollowed.has(m.game_id))
        .map((m) => ({
          user_id: user_id,
          game_id: m.game_id,
        }));

      if (newFollows.length > 0) {
        const { error: followError } = await supabase
          .from("user_game_follows")
          .insert(newFollows);

        if (!followError) {
          followedCount = newFollows.length;
        } else {
          console.error("Follow error:", followError.message);
        }
      }
    }

    // 5. Return sync results
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
        matched_to_catalog: matchedGames.length,
        newly_followed: followedCount,
        recently_played: recentGames.map((g) => ({
          name: g.name,
          appid: g.appid,
          playtime_2weeks_hours: Math.round((g.playtime_2weeks ?? 0) / 60),
          cover_url: steamAppCoverUrl(g.appid),
        })),
        matched_games: matchedGames.slice(0, 50).map((m) => ({
          name: m.name,
          game_id: m.game_id,
          playtime_hours: m.playtime_hours,
          recently_played: m.recently_played,
          cover_url: steamAppCoverUrl(m.steam_appid),
        })),
        unmatched_top_games: ownedGames
          .filter(
            (g) => !matchedGames.some((m) => m.steam_appid === g.appid),
          )
          .sort((a, b) => b.playtime_forever - a.playtime_forever)
          .slice(0, 20)
          .map((g) => ({
            name: g.name,
            appid: g.appid,
            playtime_hours: Math.round(g.playtime_forever / 60),
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
