// PatchNotes Content Pipeline — Cloudflare Worker
// Fetches content from Reddit, Twitter (via twitterapi.io), and Steam News API,
// rewrites it with Workers AI to feel original, preserves all media,
// and posts to Supabase. Runs on a 5-minute cron schedule in batches.

interface Env {
  SUPABASE_URL: string;
  SUPABASE_SERVICE_ROLE_KEY: string;
  TWITTERAPI_IO_API_KEY: string;
  STEAM_API_KEY: string;
  GAMES_POPULARITY_KEY: string;
  AI: Ai;
}

interface TwitterPost {
  id: string;
  text: string;
  author?: { userName?: string; name?: string };
  media?: Array<{
    media_url_https?: string;
    type?: string;
    video_info?: { variants?: Array<{ url?: string; bitrate?: number }> };
  }>;
  extendedEntities?: {
    media?: Array<{
      media_url_https?: string;
      type?: string;
      video_info?: { variants?: Array<{ url?: string; bitrate?: number }> };
    }>;
  };
  entities?: {
    media?: Array<{ media_url_https?: string; type?: string }>;
  };
  likeCount?: number;
  retweetCount?: number;
  replyCount?: number;
  viewCount?: number;
  createdAt?: string;
  url?: string;
  isRetweet?: boolean;
  isReply?: boolean;
}

interface BotSource {
  id: string;
  bot_user_id: string;
  source_type: string;
  source_identifier: string;
  game_id: string | null;
  last_fetched_at: string | null;
}

const REDDIT_USER_AGENT = "PatchNotes/1.0 (Cloudflare Worker Bot Pipeline)";
const MIN_SCORE = 10;
const POSTS_PER_SUBREDDIT = 5;
const TWEETS_PER_HANDLE = 5;
const MIN_LIKES = 50;
// Workers Paid plan allows 1,000 subrequests per invocation.
// Each source uses ~10 requests (1 fetch + ~3 dedup + ~3 AI rewrite + ~2 insert + 1 patch).
// 15 sources per batch uses ~150 subrequests — well within the 1,000 limit.
// With ~180 sources and 2-min cron, full cycle completes in ~24 minutes.
const BATCH_SIZE = 15;
const STEAM_NEWS_COUNT = 5;

// -- Supabase helpers --

function sbHeaders(key: string): Record<string, string> {
  return {
    apikey: key,
    "Content-Type": "application/json",
    Prefer: "return=representation",
  };
}

async function sbGet(
  env: Env,
  table: string,
  params: string,
): Promise<unknown[]> {
  const resp = await fetch(
    `${env.SUPABASE_URL}/rest/v1/${table}?${params}`,
    { headers: sbHeaders(env.SUPABASE_SERVICE_ROLE_KEY) },
  );
  if (!resp.ok) {
    throw new Error(
      `Supabase GET ${table}: ${resp.status} ${await resp.text()}`,
    );
  }
  return (await resp.json()) as unknown[];
}

async function sbInsert(
  env: Env,
  table: string,
  row: Record<string, unknown>,
): Promise<Record<string, unknown>> {
  const resp = await fetch(`${env.SUPABASE_URL}/rest/v1/${table}`, {
    method: "POST",
    headers: sbHeaders(env.SUPABASE_SERVICE_ROLE_KEY),
    body: JSON.stringify(row),
  });
  if (!resp.ok) {
    const text = await resp.text();
    throw new Error(`Supabase INSERT ${table}: ${resp.status} ${text}`);
  }
  const data = await resp.json();
  return Array.isArray(data) ? data[0] : data;
}

async function sbPatch(
  env: Env,
  table: string,
  params: string,
  body: Record<string, unknown>,
): Promise<void> {
  await fetch(`${env.SUPABASE_URL}/rest/v1/${table}?${params}`, {
    method: "PATCH",
    headers: sbHeaders(env.SUPABASE_SERVICE_ROLE_KEY),
    body: JSON.stringify(body),
  });
}

// -- AI Rewriting --

async function rewriteContent(
  ai: Ai,
  title: string,
  body: string | null,
  sourceProvider: string,
  gameTitles: string[],
): Promise<{ title: string; body: string | null; skip: boolean; game: string | null }> {
  try {
    const gameListStr = gameTitles.length > 0
      ? `\n\nKNOWN GAMES (pick the closest match if the post is about one of these, or null if none match or if the post is about gaming in general):\n${gameTitles.join(", ")}`
      : "";

    const prompt = `You are a gaming news editor. Rephrase the SOURCE POST below into a short news update. You MUST only use facts from the source — NEVER invent, fabricate, or add any information not present in the original title and body.

CRITICAL: Your rewritten title and body must be about the SAME topic as the source. If the source is about Fortnite, your output must be about Fortnite. If about PUBG, your output must be about PUBG. Do NOT substitute a different game or topic.

RULES:
1. REJECT and set "skip": true if the post is NOT about a video game, gaming news, or the gaming industry. Examples of posts to REJECT:
   - Hardware/tech deals (laptops, MacBooks, SSDs, GPUs, monitors, headsets)
   - Merchandise, clothing, toys, collectibles
   - General tech news unrelated to games (Apple, Amazon, phone releases)
   - Memes with no gaming news value
   - Job postings, giveaways, self-promotion
   When in doubt, REJECT. We only want posts about actual video games.
2. Rephrase the source into 1-2 complete sentences for the body. Keep the same meaning.
3. The title should be a short headline summarizing the source title. Do NOT change the subject.
4. Do not add hashtags, emojis, links, or URLs.
5. Set "game" to the exact game title from the KNOWN GAMES list if the post is about one of them, or null otherwise.${gameListStr}

SOURCE POST:
TITLE: ${title}
${body ? `BODY: ${body.slice(0, 500)}` : ""}

Respond ONLY with this JSON, no other text:
{"skip": false, "title": "rephrased title", "body": "rephrased body or null", "game": "exact game title or null"}`;

    const result = await ai.run("@cf/meta/llama-3.1-8b-instruct", {
      messages: [{ role: "user", content: prompt }],
      max_tokens: 500,
    });

    const text =
      typeof result === "string"
        ? result
        : (result as { response?: string })?.response ?? "";
    // Extract JSON from response
    const jsonMatch = text.match(/\{[\s\S]*\}/);
    if (jsonMatch) {
      const parsed = JSON.parse(jsonMatch[0]);
      if (parsed.skip === true) {
        return { title: "", body: null, skip: true, game: null };
      }
      return {
        title: (parsed.title as string)?.slice(0, 300) || title,
        body: parsed.body || null,
        skip: false,
        game: parsed.game || null,
      };
    }
  } catch (err) {
    console.log(`AI rewrite failed, using original: ${(err as Error).message}`);
  }
  // Fallback: return original content
  return { title, body, skip: false, game: null };
}

// -- Reddit helpers --
// Reddit blocks JSON API from datacenter IPs but serves RSS/Atom feeds.
// We parse the Atom feed which gives us: title, link, author, content snippet, updated time.
// No score/upvote data available via RSS, so we can't filter by MIN_SCORE.

interface RssRedditPost {
  id: string;
  title: string;
  body: string | null;
  permalink: string;
  author: string;
  mediaUrl: string | null;
  thumbnailUrl: string | null;
  updatedAt: string;
  subreddit: string;
}

function parseAtomFeed(xml: string, subreddit: string): RssRedditPost[] {
  const posts: RssRedditPost[] = [];
  // Match each <entry>...</entry>
  const entries = xml.match(/<entry>[\s\S]*?<\/entry>/g) ?? [];
  for (const entry of entries) {
    const tag = (name: string): string => {
      const m = entry.match(new RegExp(`<${name}[^>]*>([\\s\\S]*?)<\\/${name}>`));
      return m ? m[1].trim() : "";
    };
    const attr = (name: string, a: string): string => {
      const m = entry.match(new RegExp(`<${name}[^>]*${a}="([^"]*)"`));
      return m ? m[1] : "";
    };

    const link = attr("link", "href");
    // Extract Reddit post ID from link: /r/gaming/comments/ABC123/...
    const idMatch = link.match(/\/comments\/([a-z0-9]+)/i);
    if (!idMatch) continue;

    const title = tag("title").replace(/&amp;/g, "&").replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&#39;/g, "'").replace(/&quot;/g, '"');

    // Content is HTML-encoded; extract text and look for media
    const content = tag("content");
    const decoded = content
      .replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&amp;/g, "&")
      .replace(/&#39;/g, "'").replace(/&quot;/g, '"');

    // Extract thumbnail/image from the HTML content
    // Fully decode any remaining entities in URLs (RSS feeds can double-encode)
    const decodeEntities = (s: string): string =>
      s.replace(/&amp;/g, "&").replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&#39;/g, "'").replace(/&quot;/g, '"');

    let mediaUrl: string | null = null;
    let thumbnailUrl: string | null = null;
    const imgMatch = decoded.match(/<img\s+src="([^"]+)"/);
    if (imgMatch) {
      const imgUrl = decodeEntities(imgMatch[1]);
      if (imgUrl.includes("preview.redd.it") || imgUrl.includes("i.redd.it") || imgUrl.includes("external-preview.redd.it")) {
        mediaUrl = imgUrl;
      } else if (imgUrl.includes("thumbs.redditmedia")) {
        thumbnailUrl = imgUrl;
      }
    }

    // Extract text body (strip HTML tags)
    const textContent = decoded
      .replace(/<[^>]+>/g, " ")
      .replace(/\s+/g, " ")
      .trim()
      .slice(0, 500) || null;

    posts.push({
      id: idMatch[1],
      title,
      body: textContent && textContent.length > 30 ? textContent : null,
      permalink: link,
      author: tag("author") ? (tag("name") || "unknown") : "unknown",
      mediaUrl,
      thumbnailUrl,
      updatedAt: tag("updated"),
      subreddit,
    });
  }
  return posts;
}

async function fetchSubredditHot(
  subreddit: string,
): Promise<RssRedditPost[]> {
  const url = `https://www.reddit.com/r/${subreddit}/hot.rss?limit=${POSTS_PER_SUBREDDIT * 2}`;
  const resp = await fetch(url, {
    headers: { "User-Agent": REDDIT_USER_AGENT },
  });

  if (!resp.ok) {
    console.log(
      `Reddit RSS error for r/${subreddit}: ${resp.status} ${resp.statusText}`,
    );
    return [];
  }

  const xml = await resp.text();
  return parseAtomFeed(xml, subreddit).slice(0, POSTS_PER_SUBREDDIT);
}

// -- Twitter helpers --

async function fetchTwitterPosts(
  handle: string,
  apiKey: string,
): Promise<TwitterPost[]> {
  const url = `https://api.twitterapi.io/twitter/user/last_tweets?userName=${encodeURIComponent(handle)}&count=${TWEETS_PER_HANDLE * 2}`;
  const resp = await fetch(url, {
    headers: {
      "X-API-Key": apiKey,
      "Content-Type": "application/json",
    },
  });

  if (!resp.ok) {
    console.log(
      `Twitter API error for @${handle}: ${resp.status} ${resp.statusText}`,
    );
    return [];
  }

  const data = (await resp.json()) as {
    tweets?: TwitterPost[];
    data?: { tweets?: TwitterPost[] } | TwitterPost[];
  };
  // twitterapi.io nests tweets under data.tweets
  let tweets: TwitterPost[] = [];
  if (data?.tweets && Array.isArray(data.tweets)) {
    tweets = data.tweets;
  } else if (data?.data) {
    if (Array.isArray(data.data)) {
      tweets = data.data;
    } else if (
      typeof data.data === "object" &&
      "tweets" in data.data &&
      Array.isArray(data.data.tweets)
    ) {
      tweets = data.data.tweets;
    }
  }
  return tweets
    .filter((t) => t.isRetweet !== true && t.isReply !== true)
    .filter((t) => (t.likeCount ?? 0) >= MIN_LIKES)
    .slice(0, TWEETS_PER_HANDLE);
}

function extractTwitterMedia(
  tweet: TwitterPost,
): { mediaUrl: string | null; thumbnailUrl: string | null; isVideo: boolean } {
  // Check extendedEntities first (has video info), then entities
  const mediaItems =
    tweet.extendedEntities?.media ?? tweet.entities?.media ?? tweet.media ?? [];

  for (const m of mediaItems) {
    // Video: use the thumbnail image as media_url (app can't play raw mp4s)
    if (
      (m.type === "video" || m.type === "animated_gif") &&
      m.media_url_https
    ) {
      return {
        mediaUrl: m.media_url_https,
        thumbnailUrl: null,
        isVideo: true,
      };
    }
    // Image
    if (m.media_url_https) {
      return { mediaUrl: m.media_url_https, thumbnailUrl: null, isVideo: false };
    }
  }
  return { mediaUrl: null, thumbnailUrl: null, isVideo: false };
}

// -- Steam helpers --
// Steam News API is free (no key required) and returns patch notes,
// community announcements, and news directly from game developers.

interface SteamNewsItem {
  gid: string;
  title: string;
  url: string;
  is_external_url: boolean;
  author: string;
  contents: string;
  feedlabel: string;
  feedname: string;
  feed_type: number; // 0=external, 1=Steam community
  date: number; // Unix timestamp
  appid: number;
  tags?: string[];
}

function stripBBCode(text: string): string {
  return text
    .replace(/\[\/?\w+[^\]]*\]/g, "") // Remove BBCode tags like [b], [/b], [url=...]
    .replace(/\{STEAM_CLAN_IMAGE\}[^\s]*/g, "") // Remove Steam clan image refs
    .replace(/https?:\/\/\S+/g, "") // Remove raw URLs
    .replace(/\s+/g, " ")
    .trim();
}

async function fetchSteamNews(
  appId: string,
): Promise<SteamNewsItem[]> {
  const url = `https://api.steampowered.com/ISteamNews/GetNewsForApp/v2/?appid=${appId}&count=${STEAM_NEWS_COUNT * 2}&maxlength=600&format=json`;
  const resp = await fetch(url);

  if (!resp.ok) {
    console.log(`Steam News API error for appid ${appId}: ${resp.status} ${resp.statusText}`);
    return [];
  }

  const data = (await resp.json()) as {
    appnews?: { newsitems?: SteamNewsItem[] };
  };
  const items = data?.appnews?.newsitems ?? [];

  // Prefer official Steam community announcements (feed_type=1) over external aggregation
  // Filter out very short items (spam/empty announcements)
  return items
    .filter((item) => {
      const text = stripBBCode(item.contents);
      return text.length > 50;
    })
    .slice(0, STEAM_NEWS_COUNT);
}

function extractSteamImage(contents: string, appId: string): string | null {
  // Try to extract image from BBCode [img] tags
  const imgMatch = contents.match(/\[img\](https?:\/\/[^\[]+)\[\/img\]/);
  if (imgMatch) return imgMatch[1];

  // Try Steam clan image pattern
  const clanMatch = contents.match(/\{STEAM_CLAN_IMAGE\}(\S+)/);
  if (clanMatch) return `https://clan.akamai.steamstatic.com/images/${clanMatch[1]}`;

  // Fallback: use Steam store header image for the app
  return `https://cdn.akamai.steamstatic.com/steam/apps/${appId}/header.jpg`;
}

function buildSteamPost(
  item: SteamNewsItem,
  rewritten: { title: string; body: string | null },
  botUserId: string,
  gameId: string | null,
): Record<string, unknown> {
  const mediaUrl = extractSteamImage(item.contents, String(item.appid));
  const isPatchNotes = item.tags?.includes("patchnotes") ||
    item.feedname === "steam_community_announcements" ||
    /patch|update|hotfix|changelog/i.test(item.title);

  return {
    author_id: botUserId,
    game_id: gameId,
    type: mediaUrl ? "image" : "news",
    title: rewritten.title,
    body: rewritten.body,
    media_url: mediaUrl,
    thumbnail_url: null,
    is_system_generated: true,
    source_kind: "curated",
    source_provider: "steam",
    source_external_id: `steam_${item.appid}_${item.gid}`,
    source_handle: null,
    source_url: item.url || null,
    source_published_at: new Date(item.date * 1000).toISOString(),
    source_metadata: {
      steam_app_id: item.appid,
      feed_type: item.feed_type,
      feedlabel: item.feedlabel,
      feedname: item.feedname,
      author: item.author,
      is_patch_notes: isPatchNotes,
      tags: item.tags ?? [],
    },
  };
}

// -- Post builders --

function buildRedditPost(
  post: RssRedditPost,
  rewritten: { title: string; body: string | null },
  botUserId: string,
  gameId: string | null,
): Record<string, unknown> {
  return {
    author_id: botUserId,
    game_id: gameId,
    type: post.mediaUrl ? "image" : "news",
    title: rewritten.title,
    body: rewritten.body,
    media_url: post.mediaUrl,
    thumbnail_url: post.thumbnailUrl,
    is_system_generated: true,
    source_kind: "curated",
    source_provider: "reddit",
    source_external_id: `reddit_${post.id}`,
    source_handle: `r/${post.subreddit}`,
    source_url: post.permalink ? `https://reddit.com${post.permalink}` : null,
    source_published_at: post.updatedAt || new Date().toISOString(),
    source_metadata: {
      original_subreddit: post.subreddit,
    },
  };
}

function buildTwitterPost(
  tweet: TwitterPost,
  rewritten: { title: string; body: string | null },
  botUserId: string,
  gameId: string | null,
): Record<string, unknown> {
  const { mediaUrl, thumbnailUrl, isVideo } = extractTwitterMedia(tweet);

  return {
    author_id: botUserId,
    game_id: gameId,
    type: mediaUrl ? "image" : "news",
    title: rewritten.title,
    body: rewritten.body,
    media_url: mediaUrl,
    thumbnail_url: thumbnailUrl,
    is_system_generated: true,
    source_kind: "curated",
    source_provider: "twitter",
    source_external_id: `twitter_${tweet.id}`,
    source_handle: null,
    source_url: null,
    source_published_at: tweet.createdAt
      ? new Date(tweet.createdAt).toISOString()
      : new Date().toISOString(),
    source_metadata: {
      likes: tweet.likeCount,
      retweets: tweet.retweetCount,
      replies: tweet.replyCount,
      views: tweet.viewCount,
      original_author: tweet.author?.userName,
    },
  };
}

// -- Main logic --

interface PipelineResult {
  sourcesProcessed: number;
  postsFetched: number;
  postsCreated: number;
  postsSkipped: number;
  errors: string[];
}

async function processSource(
  env: Env,
  source: BotSource,
  result: PipelineResult,
  gameTitles: string[],
  gameMap: Map<string, string>,
): Promise<void> {
  const isTwitter = source.source_type === "twitter";
  const isReddit = source.source_type === "reddit";
  const isSteam = source.source_type === "steam";

  if (!isReddit && !isTwitter && !isSteam) return;

  // Skip Twitter sources if no API key configured — update last_fetched_at
  // so they don't block the queue
  if (isTwitter && !env.TWITTERAPI_IO_API_KEY) {
    console.log(`Skipping @${source.source_identifier} — no TWITTERAPI_IO_API_KEY set`);
    await sbPatch(env, "bot_content_sources", `id=eq.${source.id}`, {
      last_fetched_at: new Date().toISOString(),
    });
    return;
  }

  let items: Array<{
    externalId: string;
    originalTitle: string;
    originalBody: string | null;
    provider: string;
    buildPost: (
      rewritten: { title: string; body: string | null },
    ) => Record<string, unknown>;
  }> = [];

  if (isReddit) {
    const posts = await fetchSubredditHot(source.source_identifier);
    result.postsFetched += posts.length;
    if (posts.length > 0) {
      console.log(
        `r/${source.source_identifier}: ${posts.length} posts via RSS`,
      );
    }
    items = posts.map((post) => ({
      externalId: `reddit_${post.id}`,
      originalTitle: post.title,
      originalBody: post.body,
      provider: "reddit",
      buildPost: (rewritten: { title: string; body: string | null }) =>
        buildRedditPost(post, rewritten, source.bot_user_id, source.game_id),
    }));
  }

  if (isTwitter && env.TWITTERAPI_IO_API_KEY) {
    const tweets = await fetchTwitterPosts(
      source.source_identifier,
      env.TWITTERAPI_IO_API_KEY,
    );
    result.postsFetched += tweets.length;
    if (tweets.length > 0) {
      console.log(
        `@${source.source_identifier}: ${tweets.length} qualifying tweets`,
      );
    }
    items = tweets.map((tweet) => ({
      externalId: `twitter_${tweet.id}`,
      originalTitle: tweet.text?.slice(0, 300) ?? "",
      originalBody: null,
      provider: "twitter",
      buildPost: (rewritten) =>
        buildTwitterPost(tweet, rewritten, source.bot_user_id, source.game_id),
    }));
  }

  if (isSteam) {
    // source_identifier is the Steam app ID (e.g. "730" for CS2)
    const newsItems = await fetchSteamNews(source.source_identifier);
    result.postsFetched += newsItems.length;
    if (newsItems.length > 0) {
      console.log(
        `Steam appid ${source.source_identifier}: ${newsItems.length} news items`,
      );
    }
    items = newsItems.map((item) => ({
      externalId: `steam_${item.appid}_${item.gid}`,
      originalTitle: item.title,
      originalBody: stripBBCode(item.contents).slice(0, 500) || null,
      provider: "steam",
      buildPost: (rewritten: { title: string; body: string | null }) =>
        buildSteamPost(item, rewritten, source.bot_user_id, source.game_id),
    }));
  }

  for (const item of items) {
    // Check dedup
    const existing = await sbGet(
      env,
      "bot_post_log",
      `source_external_id=eq.${item.externalId}&select=id&limit=1`,
    );
    if (existing.length > 0) {
      result.postsSkipped++;
      continue;
    }

    // Rewrite with AI (may skip non-gaming content, may tag a game)
    const rewritten = await rewriteContent(
      env.AI,
      item.originalTitle,
      item.originalBody,
      item.provider,
      gameTitles,
    );

    if (rewritten.skip) {
      console.log(`Skipped non-gaming content: "${item.originalTitle.slice(0, 80)}"`);
      result.postsSkipped++;
      continue;
    }

    const appPost = item.buildPost(rewritten);

    // AI game-tagging: only use AI's game guess when the source has no game_id
    // (e.g. posts from general subreddits like r/gaming). When a source already has
    // a game_id from bot_content_sources, trust the subreddit mapping — the AI
    // (Llama 3.1 8B) frequently hallucinates wrong games (e.g. tagging PUBG as Fortnite).
    if (rewritten.game && !source.game_id) {
      const matchedGameId = gameMap.get(rewritten.game.toLowerCase());
      if (matchedGameId) {
        appPost.game_id = matchedGameId;
        console.log(`AI tagged "${rewritten.title.slice(0, 50)}" → ${rewritten.game}`);
      }
    }

    try {
      const inserted = await sbInsert(env, "posts", appPost);
      await sbInsert(env, "bot_post_log", {
        bot_user_id: source.bot_user_id,
        source_type: source.source_type,
        source_external_id: item.externalId,
        post_id: (inserted as { id: string }).id,
      });
      result.postsCreated++;
    } catch (err) {
      const errMsg = (err as Error).message;
      if (errMsg.includes("409") || errMsg.includes("23505")) {
        result.postsSkipped++;
        try {
          await sbInsert(env, "bot_post_log", {
            bot_user_id: source.bot_user_id,
            source_type: source.source_type,
            source_external_id: item.externalId,
            post_id: "00000000-0000-0000-0000-000000000000",
          });
        } catch {
          // dedup log exists or FK issue — will skip next time
        }
      } else {
        console.log(`Insert error: ${errMsg}`);
        result.errors.push(errMsg);
      }
    }
  }

  // Update last_fetched_at
  await sbPatch(env, "bot_content_sources", `id=eq.${source.id}`, {
    last_fetched_at: new Date().toISOString(),
  });
}

async function fetchContent(env: Env): Promise<PipelineResult> {
  // Load game catalog for AI game-tagging (1 subrequest, cached for the batch)
  const gamesRaw = (await sbGet(
    env,
    "games",
    "select=id,title&order=title.asc",
  )) as Array<{ id: string; title: string }>;
  const gameMap = new Map(gamesRaw.map((g) => [g.title.toLowerCase(), g.id]));
  const gameTitles = gamesRaw.map((g) => g.title);
  console.log(`Loaded ${gameTitles.length} games for AI tagging`);

  // Fetch oldest-refreshed sources first (both reddit and twitter),
  // limited to BATCH_SIZE to stay within Cloudflare's 50 subrequest limit.
  const sources = (await sbGet(
    env,
    "bot_content_sources",
    `is_active=eq.true&select=id,bot_user_id,source_type,source_identifier,game_id,last_fetched_at&order=last_fetched_at.asc.nullsfirst&limit=${BATCH_SIZE}`,
  )) as BotSource[];

  console.log(
    `Processing batch of ${sources.length} sources (oldest-first, limit ${BATCH_SIZE})`,
  );

  const result: PipelineResult = {
    sourcesProcessed: sources.length,
    postsFetched: 0,
    postsCreated: 0,
    postsSkipped: 0,
    errors: [],
  };

  for (const source of sources) {
    try {
      await processSource(env, source, result, gameTitles, gameMap);
    } catch (err) {
      const msg = `${source.source_type}/${source.source_identifier}: ${(err as Error).message}`;
      console.log(msg);
      result.errors.push(msg);
    }
  }

  return result;
}

// -- Steam catalog enrichment --
// Fetches app details + review counts from Steam to enrich game metadata.
// Called via POST /enrich (not on every cron tick — rate-limited by Steam).

interface SteamAppDetails {
  name: string;
  steam_appid: number;
  short_description: string;
  header_image: string;
  screenshots: Array<{ path_thumbnail: string; path_full: string }>;
  genres: Array<{ id: string; description: string }>;
  release_date: { coming_soon: boolean; date: string };
  metacritic?: { score: number; url: string };
  developers?: string[];
  publishers?: string[];
  categories?: Array<{ id: number; description: string }>;
  recommendations?: { total: number };
}

interface SteamReviewSummary {
  total_reviews: number;
  total_positive: number;
  total_negative: number;
  review_score_desc: string;
}

// Minimum review count for Steam discovery to create a new game community.
// Games added via subreddit sources bypass this — they already have community demand.
// 10k reviews ≈ mid-tier popular game; high enough to avoid niche/indie spam,
// low enough to catch legitimate titles that aren't AAA blockbusters.
const PILL_REVIEW_THRESHOLD = 10_000;

// Search Steam store for an app ID by game title
async function searchSteamAppId(
  title: string,
): Promise<{ appid: number; name: string } | null> {
  const url = `https://store.steampowered.com/api/storesearch/?term=${encodeURIComponent(title)}&l=english&cc=US`;
  try {
    const resp = await fetch(url);
    if (!resp.ok) return null;
    const data = (await resp.json()) as {
      total: number;
      items: Array<{ id: number; name: string }>;
    };
    if (!data.items?.length) return null;
    // Return first result — Steam search ranks by relevance
    return { appid: data.items[0].id, name: data.items[0].name };
  } catch {
    return null;
  }
}

async function fetchSteamAppDetails(
  appId: number,
): Promise<SteamAppDetails | null> {
  const resp = await fetch(
    `https://store.steampowered.com/api/appdetails?appids=${appId}`,
  );
  if (!resp.ok) return null;
  const data = (await resp.json()) as Record<
    string,
    { success: boolean; data?: SteamAppDetails }
  >;
  const entry = data[String(appId)];
  return entry?.success ? (entry.data ?? null) : null;
}

async function fetchSteamReviewSummary(
  appId: number,
): Promise<SteamReviewSummary | null> {
  const resp = await fetch(
    `https://store.steampowered.com/appreviews/${appId}?json=1&num_per_page=0&language=all`,
  );
  if (!resp.ok) return null;
  const data = (await resp.json()) as {
    success: number;
    query_summary?: SteamReviewSummary;
  };
  return data.success === 1 ? (data.query_summary ?? null) : null;
}

async function enrichGameCatalog(
  env: Env,
): Promise<{
  enriched: number;
  skipped: number;
  discovered: number;
  errors: string[];
}> {
  const result = { enriched: 0, skipped: 0, discovered: 0, errors: [] as string[] };

  // Fetch games that have steam_app_id set, prioritizing un-enriched games first
  const games = (await sbGet(
    env,
    "games",
    "steam_app_id=not.is.null&select=id,title,steam_app_id,cover_image_url,genre,release_date,enriched_at&order=enriched_at.asc.nullsfirst&limit=15",
  )) as Array<{
    id: string;
    title: string;
    steam_app_id: number;
    cover_image_url: string | null;
    genre: string | null;
    release_date: string | null;
    enriched_at: string | null;
  }>;

  console.log(`Enriching batch of ${games.length} games (oldest-enriched first)`);

  for (const game of games) {
    try {
      const [details, reviews] = await Promise.all([
        fetchSteamAppDetails(game.steam_app_id),
        fetchSteamReviewSummary(game.steam_app_id),
      ]);

      if (!details) {
        result.skipped++;
        continue;
      }

      // Safety check: verify the Steam app name roughly matches our game title
      // to prevent wrong cover art from mismatched steam_app_ids
      const steamName = details.name.toLowerCase().replace(/[^a-z0-9]/g, "");
      const ourName = game.title.toLowerCase().replace(/[^a-z0-9]/g, "");
      const nameMatches =
        steamName.includes(ourName.slice(0, 8)) ||
        ourName.includes(steamName.slice(0, 8));

      if (!nameMatches) {
        console.log(
          `WARNING: Steam app ${game.steam_app_id} name "${details.name}" does not match game "${game.title}" — skipping cover art update`,
        );
      }

      // Build update payload — only set fields that add value
      const updates: Record<string, unknown> = {};

      // Use Steam's portrait library capsule (600x900) as primary cover art.
      // Store the API's header_image (with unique hash) as fallback for games
      // where the portrait capsule doesn't exist on Steam's CDN.
      if (nameMatches) {
        const portraitUrl = `https://cdn.akamai.steamstatic.com/steam/apps/${game.steam_app_id}/library_600x900.jpg`;
        updates.cover_image_url = portraitUrl;
        if (details.header_image) {
          updates.cover_image_fallback_url = details.header_image;
        }
      }

      // Enrich genre if missing
      if (!game.genre && details.genres?.length) {
        updates.genre = details.genres[0].description;
      }

      // Enrich release date if missing and Steam has one
      if (!game.release_date && details.release_date?.date) {
        const parsed = parseSteamDate(details.release_date.date);
        if (parsed) updates.release_date = parsed;
      }

      // Always update steam_review_count and steam_review_score for popularity gating
      if (reviews) {
        updates.steam_review_count = reviews.total_reviews;
        updates.steam_review_score = reviews.review_score_desc;
        // Auto-promote to community when a game crosses the review threshold
        if (reviews.total_reviews >= PILL_REVIEW_THRESHOLD) {
          updates.has_community = true;
        }
      }

      if (details.metacritic?.score) {
        updates.metacritic_score = details.metacritic.score;
      }

      if (Object.keys(updates).length > 0) {
        updates.enriched_at = new Date().toISOString();
        await sbPatch(env, "games", `id=eq.${game.id}`, updates);
        result.enriched++;
        console.log(
          `Enriched "${game.title}": ${Object.keys(updates).join(", ")}`,
        );
      } else {
        result.skipped++;
      }
    } catch (err) {
      const msg = `${game.title}: ${(err as Error).message}`;
      console.log(`Enrich error: ${msg}`);
      result.errors.push(msg);
    }
  }

  return result;
}

// -- Steam game discovery --
// Separate endpoint so it doesn't compete with enrichment for the 50 subrequest limit.
// Pulls upcoming/new/popular games from Steam featured categories and adds them to the catalog.

async function discoverGames(
  env: Env,
): Promise<{ discovered: number; linked: number; skipped: number; errors: string[] }> {
  const result = { discovered: 0, linked: 0, skipped: 0, errors: [] as string[] };

  // Load all existing games to avoid duplicates by app ID or title
  const existingGames = (await sbGet(
    env,
    "games",
    "select=id,title,steam_app_id",
  )) as Array<{ id: string; title: string; steam_app_id: number | null }>;
  const existingAppIds = new Set(
    existingGames.filter((g) => g.steam_app_id).map((g) => g.steam_app_id!),
  );
  const existingTitles = new Map(
    existingGames.map((g) => [g.title.toLowerCase(), g.id]),
  );
  console.log(`${existingGames.length} games in catalog (${existingAppIds.size} with steam IDs)`);

  // Phase 1: Link existing catalog games that are missing steam_app_id.
  // Use Steam's store search API to find app IDs, then fetch details for release dates.
  const unlinkedGames = existingGames.filter((g) => !g.steam_app_id);
  let subrequestsUsed = 1; // 1 for the games query above
  const MAX_SUBREQUESTS = 900; // Workers Paid allows 1,000; leave headroom

  for (const game of unlinkedGames) {
    if (subrequestsUsed + 2 > MAX_SUBREQUESTS) {
      console.log(`Stopping link phase at subrequest limit (${subrequestsUsed} used)`);
      break;
    }

    try {
      const searchResult = await searchSteamAppId(game.title);
      subrequestsUsed++;
      if (!searchResult) {
        console.log(`No Steam match for "${game.title}"`);
        continue;
      }

      // Verify the search result matches and isn't already in our catalog
      if (existingAppIds.has(searchResult.appid)) continue;

      // Fetch full details for release date and metadata
      const details = await fetchSteamAppDetails(searchResult.appid);
      subrequestsUsed++;
      if (!details) continue;

      // Fuzzy name check — ensure it's actually the right game
      const searchName = details.name.toLowerCase().replace(/[^a-z0-9]/g, "");
      const catalogName = game.title.toLowerCase().replace(/[^a-z0-9]/g, "");
      if (!searchName.includes(catalogName) && !catalogName.includes(searchName)) {
        console.log(`Name mismatch: "${game.title}" vs Steam "${details.name}" — skipping`);
        continue;
      }

      const releaseDate = details.release_date?.date
        ? parseSteamDate(details.release_date.date)
        : null;
      const coverUrl = `https://cdn.akamai.steamstatic.com/steam/apps/${searchResult.appid}/library_600x900.jpg`;

      await sbPatch(env, "games", `id=eq.${game.id}`, {
        steam_app_id: searchResult.appid,
        cover_image_url: coverUrl,
        cover_image_fallback_url: details.header_image ?? null,
        genre: details.genres?.[0]?.description ?? null,
        ...(releaseDate ? { release_date: releaseDate } : {}),
        metacritic_score: details.metacritic?.score ?? null,
        enriched_at: new Date().toISOString(),
      });
      subrequestsUsed++;
      existingAppIds.add(searchResult.appid);
      result.linked++;
      console.log(
        `Linked "${game.title}" → Steam "${details.name}" (appid ${searchResult.appid}, release: ${releaseDate ?? "TBD"})`,
      );
    } catch (err) {
      result.errors.push(`link ${game.title}: ${(err as Error).message}`);
    }
  }

  // Phase 2: Discover new games from Steam featured categories if we have subrequests left
  if (subrequestsUsed + 2 > MAX_SUBREQUESTS) {
    console.log(`No subrequests left for featured discovery (${subrequestsUsed} used)`);
    return result;
  }

  const featResp = await fetch(
    "https://store.steampowered.com/api/featuredcategories/",
  );
  subrequestsUsed++;
  if (!featResp.ok) {
    result.errors.push(`featured categories: ${featResp.status}`);
    return result;
  }

  const featData = (await featResp.json()) as Record<
    string,
    { name?: string; items?: Array<{ id: number; name: string }> }
  >;

  // Collect unique candidate app IDs across all categories
  const candidates: Array<{ id: number; name: string; category: string }> = [];
  for (const category of ["coming_soon", "top_sellers", "new_releases"]) {
    const items = featData[category]?.items ?? [];
    for (const item of items) {
      if (existingAppIds.has(item.id)) continue;
      if (candidates.some((c) => c.id === item.id)) continue;
      candidates.push({ id: item.id, name: item.name, category });
    }
  }

  console.log(`${candidates.length} new candidates from Steam featured`);

  for (const candidate of candidates) {
    if (subrequestsUsed + 2 > MAX_SUBREQUESTS) {
      console.log(`Stopping discovery at subrequest limit (${subrequestsUsed} used)`);
      break;
    }

    try {
      // Fetch review count for popularity signal
      const reviews = await fetchSteamReviewSummary(candidate.id);
      subrequestsUsed++;
      const reviewCount = reviews?.total_reviews ?? 0;

      // All games go into the catalog (browsable, favoritable).
      // Only games above the review threshold get has_community = true (followable, bot-worthy).
      const hasCommunity = reviewCount >= PILL_REVIEW_THRESHOLD;

      // Fetch full details
      const details = await fetchSteamAppDetails(candidate.id);
      subrequestsUsed++;
      if (!details) {
        result.skipped++;
        continue;
      }

      const releaseDate = details.release_date?.date
        ? parseSteamDate(details.release_date.date)
        : null;

      // Use portrait library capsule for cover art
      const coverUrl = `https://cdn.akamai.steamstatic.com/steam/apps/${candidate.id}/library_600x900.jpg`;

      // Check if a game with this title already exists (without steam_app_id)
      const existingId = existingTitles.get(details.name.toLowerCase());
      if (existingId) {
        // Update the existing game rather than creating a duplicate
        await sbPatch(env, "games", `id=eq.${existingId}`, {
          steam_app_id: candidate.id,
          cover_image_url: coverUrl,
          cover_image_fallback_url: details.header_image ?? null,
          genre: details.genres?.[0]?.description ?? null,
          release_date: releaseDate ?? undefined,
          steam_review_count: reviewCount,
          steam_review_score: reviews?.review_score_desc ?? null,
          metacritic_score: details.metacritic?.score ?? null,
          has_community: hasCommunity,
          enriched_at: new Date().toISOString(),
        });
        console.log(
          `Linked existing "${details.name}" to Steam appid ${candidate.id} (community: ${hasCommunity})`,
        );
      } else {
        await sbInsert(env, "games", {
          title: details.name,
          steam_app_id: candidate.id,
          cover_image_url: coverUrl,
          cover_image_fallback_url: details.header_image ?? null,
          genre: details.genres?.[0]?.description ?? null,
          release_date: releaseDate,
          category: "PC",
          steam_review_count: reviewCount,
          steam_review_score: reviews?.review_score_desc ?? null,
          metacritic_score: details.metacritic?.score ?? null,
          has_community: hasCommunity,
          enriched_at: new Date().toISOString(),
        });
      }
      subrequestsUsed++;
      existingAppIds.add(candidate.id);
      result.discovered++;
      console.log(
        `Discovered "${details.name}" (${reviewCount} reviews, community: ${hasCommunity}, ${candidate.category})`,
      );
    } catch (err) {
      const msg = (err as Error).message;
      if (!msg.includes("409") && !msg.includes("23505")) {
        result.errors.push(`discover ${candidate.name}: ${msg}`);
      }
    }
  }

  return result;
}

function parseSteamDate(dateStr: string): string | null {
  // Steam dates come in formats like "Feb 24, 2022" or "Q1 2026" or "Coming Soon"
  // Try to parse common formats into YYYY-MM-DD
  const match = dateStr.match(
    /(\w+)\s+(\d{1,2}),?\s+(\d{4})/,
  );
  if (match) {
    const months: Record<string, string> = {
      Jan: "01", Feb: "02", Mar: "03", Apr: "04",
      May: "05", Jun: "06", Jul: "07", Aug: "08",
      Sep: "09", Oct: "10", Nov: "11", Dec: "12",
    };
    const m = months[match[1]];
    if (m) {
      return `${match[3]}-${m}-${match[2].padStart(2, "0")}`;
    }
  }
  return null;
}

// -- Hype signal sync (games-popularity.com) --
// Uses Steam wishlist rankings as a hype signal for unreleased games.
// Top 50 wishlisted games get has_community = true automatically.
// Also discovers new games from the wishlist/seller lists and adds them to the catalog.

const WISHLIST_COMMUNITY_THRESHOLD = 50; // top N wishlisted → community

interface PopularityEntry {
  position: number;
  gameName: string;
  steamId: string;
}

interface PopularityResponse {
  validTimeUtc: string;
  data: PopularityEntry[];
}

async function syncHypeSignals(
  env: Env,
): Promise<{ promoted: number; discovered: number; errors: string[] }> {
  const result = { promoted: 0, discovered: 0, errors: [] as string[] };
  const apiKey = env.GAMES_POPULARITY_KEY;
  const base = "https://games-popularity.com/swagger/api";

  // Fetch top wishlisted games
  let wishlistEntries: PopularityEntry[] = [];
  try {
    const resp = await fetch(`${base}/top-wishlist?apiKey=${apiKey}`);
    if (!resp.ok) {
      result.errors.push(`top-wishlist: ${resp.status}`);
      return result;
    }
    const body = (await resp.json()) as PopularityResponse;
    // Deduplicate (API returns duplicates)
    const seen = new Set<string>();
    for (const entry of body.data) {
      if (!seen.has(entry.steamId)) {
        seen.add(entry.steamId);
        wishlistEntries.push(entry);
      }
    }
  } catch (err) {
    result.errors.push(`top-wishlist: ${(err as Error).message}`);
    return result;
  }

  console.log(`${wishlistEntries.length} unique wishlisted games from API`);

  // Load existing games for dedup
  const existingGames = (await sbGet(
    env,
    "games",
    "select=id,title,steam_app_id,has_community",
  )) as Array<{ id: string; title: string; steam_app_id: number | null; has_community: boolean }>;
  const byAppId = new Map(
    existingGames.filter((g) => g.steam_app_id).map((g) => [g.steam_app_id!, g]),
  );
  const byTitle = new Map(
    existingGames.map((g) => [g.title.toLowerCase(), g]),
  );

  // Process top wishlisted games
  for (const entry of wishlistEntries) {
    const appId = parseInt(entry.steamId, 10);
    if (isNaN(appId)) continue;

    const shouldBeCommunity = entry.position <= WISHLIST_COMMUNITY_THRESHOLD;
    const existing = byAppId.get(appId) ?? byTitle.get(entry.gameName.toLowerCase());

    if (existing) {
      // Game exists — promote to community if in top N and not already
      if (shouldBeCommunity && !existing.has_community) {
        try {
          await sbPatch(env, "games", `id=eq.${existing.id}`, {
            has_community: true,
          });
          result.promoted++;
          console.log(
            `Promoted "${entry.gameName}" to community (wishlist #${entry.position})`,
          );
        } catch (err) {
          result.errors.push(`promote ${entry.gameName}: ${(err as Error).message}`);
        }
      }
    } else {
      // New game — add to catalog. Only top 200 wishlisted are worth adding
      // to keep catalog manageable.
      if (entry.position > 200) continue;

      try {
        // Fetch Steam details for release date, genre, etc.
        const details = await fetchSteamAppDetails(appId);
        const releaseDate = details?.release_date?.date
          ? parseSteamDate(details.release_date.date)
          : null;
        const coverUrl = `https://cdn.akamai.steamstatic.com/steam/apps/${appId}/library_600x900.jpg`;

        await sbInsert(env, "games", {
          title: details?.name ?? entry.gameName,
          steam_app_id: appId,
          cover_image_url: coverUrl,
          cover_image_fallback_url: details?.header_image ?? null,
          genre: details?.genres?.[0]?.description ?? null,
          release_date: releaseDate,
          category: "PC",
          has_community: shouldBeCommunity,
          enriched_at: new Date().toISOString(),
        });
        byAppId.set(appId, { id: "", title: entry.gameName, steam_app_id: appId, has_community: shouldBeCommunity });
        result.discovered++;
        console.log(
          `Discovered "${entry.gameName}" from wishlist #${entry.position} (community: ${shouldBeCommunity})`,
        );
      } catch (err) {
        const msg = (err as Error).message;
        if (!msg.includes("409") && !msg.includes("23505")) {
          result.errors.push(`discover ${entry.gameName}: ${msg}`);
        }
      }
    }
  }

  return result;
}

// -- Worker entry points --

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    // Require service role key as bearer token to prevent unauthenticated access
    const authHeader = request.headers.get("Authorization");
    if (authHeader !== `Bearer ${env.SUPABASE_SERVICE_ROLE_KEY}`) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401,
        headers: { "Content-Type": "application/json" },
      });
    }

    const url = new URL(request.url);

    // POST /enrich — run Steam catalog enrichment (metadata, cover art, reviews)
    if (url.pathname === "/enrich") {
      const result = await enrichGameCatalog(env);
      return new Response(JSON.stringify(result, null, 2), {
        headers: { "Content-Type": "application/json" },
      });
    }

    // POST /discover — find new games from Steam featured categories
    if (url.pathname === "/discover") {
      const result = await discoverGames(env);
      return new Response(JSON.stringify(result, null, 2), {
        headers: { "Content-Type": "application/json" },
      });
    }

    // POST /hype — use games-popularity.com wishlist rankings to promote upcoming games
    if (url.pathname === "/hype") {
      const result = await syncHypeSignals(env);
      return new Response(JSON.stringify(result, null, 2), {
        headers: { "Content-Type": "application/json" },
      });
    }

    // Default: run content pipeline
    const result = await fetchContent(env);
    return new Response(JSON.stringify(result, null, 2), {
      headers: { "Content-Type": "application/json" },
    });
  },

  async scheduled(
    _event: ScheduledEvent,
    env: Env,
    ctx: ExecutionContext,
  ): Promise<void> {
    ctx.waitUntil(
      fetchContent(env).then((result) => {
        console.log("Cron result:", JSON.stringify(result));
      }),
    );
  },
};
