// PatchNotes Content Pipeline — Cloudflare Worker
// Fetches content from Reddit and Twitter (via twitterapi.io),
// rewrites it with Workers AI to feel original, preserves all media,
// and posts to Supabase. Runs on a 5-minute cron schedule in batches.

interface Env {
  SUPABASE_URL: string;
  SUPABASE_SERVICE_ROLE_KEY: string;
  TWITTERAPI_IO_API_KEY: string;
  AI: Ai;
}

interface RedditPost {
  id: string;
  title: string;
  selftext: string;
  url: string;
  permalink: string;
  author: string;
  score: number;
  num_comments: number;
  created_utc: number;
  thumbnail: string;
  preview?: {
    images?: Array<{
      source?: { url: string; width: number; height: number };
    }>;
  };
  is_self: boolean;
  link_flair_text?: string;
  subreddit: string;
  domain: string;
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
// Cloudflare free tier allows 50 subrequests per invocation.
// Each source uses ~6 requests (1 fetch + ~3 dedup + ~1 insert + 1 patch).
// 4 sources per batch stays safely under 50.
const BATCH_SIZE = 4;

// -- Supabase helpers --

function sbHeaders(key: string): Record<string, string> {
  return {
    apikey: key,
    Authorization: `Bearer ${key}`,
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
): Promise<{ title: string; body: string | null }> {
  try {
    const prompt = `You are a gaming news editor for a social app called PatchNotes. Rewrite the following ${sourceProvider} post as a short, original-sounding news update. Keep it concise and punchy. If a specific source, journalist, or insider is mentioned, credit them inline (e.g., "According to IGN..." or "Insider Tom Henderson reports..."). Do not add hashtags, emojis, or links. Preserve all factual claims and key details. Do not editorialize or add opinions.

TITLE: ${title}
${body ? `BODY: ${body.slice(0, 500)}` : ""}

Respond in this exact JSON format only, no other text:
{"title": "rewritten title here", "body": "rewritten body here or null if no body needed"}`;

    const result = await ai.run("@cf/meta/llama-3.1-8b-instruct", {
      messages: [{ role: "user", content: prompt }],
      max_tokens: 300,
    });

    const text =
      typeof result === "string"
        ? result
        : (result as { response?: string })?.response ?? "";
    // Extract JSON from response
    const jsonMatch = text.match(/\{[\s\S]*\}/);
    if (jsonMatch) {
      const parsed = JSON.parse(jsonMatch[0]);
      return {
        title: (parsed.title as string)?.slice(0, 300) || title,
        body: parsed.body || null,
      };
    }
  } catch (err) {
    console.log(`AI rewrite failed, using original: ${(err as Error).message}`);
  }
  // Fallback: return original content
  return { title, body };
}

// -- Reddit helpers --

async function fetchSubredditHot(
  subreddit: string,
): Promise<RedditPost[]> {
  const url = `https://www.reddit.com/r/${subreddit}/hot.json?limit=${POSTS_PER_SUBREDDIT * 2}&raw_json=1`;
  const resp = await fetch(url, {
    headers: { "User-Agent": REDDIT_USER_AGENT },
  });

  if (!resp.ok) {
    console.log(
      `Reddit API error for r/${subreddit}: ${resp.status} ${resp.statusText}`,
    );
    return [];
  }

  const data = (await resp.json()) as {
    data?: { children?: Array<{ data: RedditPost }> };
  };
  return (data?.data?.children ?? [])
    .map((child) => child.data)
    .filter(
      (post) => !post.is_self || (post.selftext && post.selftext.length > 20),
    )
    .filter((post) => post.score >= MIN_SCORE)
    .slice(0, POSTS_PER_SUBREDDIT);
}

function extractRedditMediaUrl(post: RedditPost): string | null {
  if (post.preview?.images?.[0]?.source?.url) {
    return post.preview.images[0].source.url;
  }
  if (
    post.thumbnail &&
    post.thumbnail.startsWith("http") &&
    !post.thumbnail.includes("self") &&
    !post.thumbnail.includes("default")
  ) {
    return post.thumbnail;
  }
  if (/\.(jpg|jpeg|png|gif|webp)(\?|$)/i.test(post.url)) {
    return post.url;
  }
  return null;
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

// -- Post builders --

function buildRedditPost(
  post: RedditPost,
  rewritten: { title: string; body: string | null },
  botUserId: string,
  gameId: string | null,
): Record<string, unknown> {
  const mediaUrl = extractRedditMediaUrl(post);

  return {
    author_id: botUserId,
    game_id: gameId,
    type: mediaUrl ? "image" : "news",
    title: rewritten.title,
    body: rewritten.body,
    media_url: mediaUrl,
    thumbnail_url: post.thumbnail?.startsWith("http") ? post.thumbnail : null,
    is_system_generated: true,
    source_kind: "curated",
    source_provider: "reddit",
    source_external_id: `reddit_${post.id}`,
    source_handle: null,
    source_url: null,
    source_published_at: new Date(post.created_utc * 1000).toISOString(),
    source_metadata: {
      reddit_score: post.score,
      reddit_comments: post.num_comments,
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
): Promise<void> {
  const isTwitter = source.source_type === "twitter";
  const isReddit = source.source_type === "reddit";

  if (!isReddit && !isTwitter) return;

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
        `r/${source.source_identifier}: ${posts.length} qualifying posts`,
      );
    }
    items = posts.map((post) => ({
      externalId: `reddit_${post.id}`,
      originalTitle: post.title,
      originalBody: post.is_self ? post.selftext.slice(0, 2000) : null,
      provider: "reddit",
      buildPost: (rewritten) =>
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

    // Rewrite with AI
    const rewritten = await rewriteContent(
      env.AI,
      item.originalTitle,
      item.originalBody,
      item.provider,
    );

    const appPost = item.buildPost(rewritten);

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
      await processSource(env, source, result);
    } catch (err) {
      const msg = `${source.source_type}/${source.source_identifier}: ${(err as Error).message}`;
      console.log(msg);
      result.errors.push(msg);
    }
  }

  return result;
}

// -- Worker entry points --

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
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
