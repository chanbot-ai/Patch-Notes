import { createClient } from "npm:@supabase/supabase-js@2";

type SyncRequest = {
  handles?: string[];
  perHandleLimit?: number;
  maxHandles?: number;
  maxTotalTweets?: number;
  dryRun?: boolean;
};

type NormalizedTweet = {
  provider: "twitterapi.io";
  provider_post_id: string;
  source_handle: string;
  source_account_id: string | null;
  author_handle: string | null;
  author_name: string | null;
  author_avatar_url: string | null;
  body: string;
  canonical_url: string | null;
  media_urls: string[];
  metrics: Record<string, unknown>;
  published_at: string;
  fetched_at: string;
  synced_at: string;
  raw_payload: Record<string, unknown>;
  updated_at: string;
};

type ProviderResponse =
  | { tweets?: unknown[]; data?: unknown[] | { tweets?: unknown[] } }
  | Record<string, unknown>;

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body, null, 2), {
    status,
    headers: { "content-type": "application/json; charset=utf-8" },
  });

const clamp = (value: number, min: number, max: number) =>
  Math.min(max, Math.max(min, value));

const cleanHandle = (value: string) =>
  value.trim().replace(/^@+/, "").toLowerCase();

function parseAllowedHandles(raw: string | undefined): Set<string> {
  if (!raw) return new Set();
  return new Set(
    raw
      .split(",")
      .map(cleanHandle)
      .filter((value) => value.length > 0),
  );
}

function parsePositiveIntEnv(name: string): number | null {
  const raw = Deno.env.get(name)?.trim();
  if (!raw) return null;
  const parsed = Number.parseInt(raw, 10);
  if (!Number.isFinite(parsed) || parsed <= 0) {
    throw new Error(`Invalid positive integer env for ${name}: ${raw}`);
  }
  return parsed;
}

function coerceString(
  raw: Record<string, unknown>,
  keys: string[],
): string | null {
  for (const key of keys) {
    const value = raw[key];
    if (typeof value === "string" && value.trim().length > 0) return value.trim();
    if (typeof value === "number") return String(value);
  }
  return null;
}

function coerceNumber(
  raw: Record<string, unknown>,
  keys: string[],
): number | null {
  for (const key of keys) {
    const value = raw[key];
    if (typeof value === "number" && Number.isFinite(value)) return value;
    if (typeof value === "string" && value.trim().length > 0) {
      const parsed = Number(value);
      if (Number.isFinite(parsed)) return parsed;
    }
  }
  return null;
}

function coerceDate(
  raw: Record<string, unknown>,
  keys: string[],
): string | null {
  for (const key of keys) {
    const value = raw[key];
    if (typeof value !== "string" || value.trim().length === 0) continue;
    const parsed = new Date(value);
    if (!Number.isNaN(parsed.getTime())) return parsed.toISOString();
  }
  return null;
}

function extractTweetArray(payload: ProviderResponse): Record<string, unknown>[] {
  const direct = Array.isArray(payload.tweets) ? payload.tweets : null;
  if (direct) return direct.filter(isRecord);

  if (Array.isArray(payload.data)) {
    return payload.data.filter(isRecord);
  }

  if (isRecord(payload.data) && Array.isArray(payload.data.tweets)) {
    return payload.data.tweets.filter(isRecord);
  }

  return [];
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function extractMediaURLs(tweet: Record<string, unknown>): string[] {
  const urls = new Set<string>();

  const maybeArrays: unknown[] = [];
  if (Array.isArray(tweet.media)) maybeArrays.push(tweet.media);
  if (isRecord(tweet.extendedEntities) && Array.isArray(tweet.extendedEntities.media)) {
    maybeArrays.push(tweet.extendedEntities.media);
  }
  if (isRecord(tweet.entities) && Array.isArray(tweet.entities.media)) {
    maybeArrays.push(tweet.entities.media);
  }

  for (const rawArray of maybeArrays) {
    for (const item of rawArray) {
      if (!isRecord(item)) continue;
      const url = coerceString(item, [
        "media_url_https",
        "media_url",
        "url",
        "preview_image_url",
      ]);
      if (url) urls.add(url);
    }
  }

  return Array.from(urls);
}

function normalizeTweet(
  tweet: Record<string, unknown>,
  sourceHandle: string,
  nowISO: string,
): NormalizedTweet | null {
  const id = coerceString(tweet, ["id", "tweet_id", "tweetId", "rest_id"]);
  if (!id) return null;

  const author = isRecord(tweet.author)
    ? tweet.author
    : isRecord(tweet.user)
    ? tweet.user
    : {};

  const authorHandle =
    coerceString(author, ["userName", "username", "screen_name", "handle"]) ??
    coerceString(tweet, ["author_username", "username", "screen_name"]);
  const authorName =
    coerceString(author, ["name", "display_name"]) ??
    coerceString(tweet, ["author_name"]);
  const authorAvatarURL =
    coerceString(author, ["profilePicture", "profile_image_url_https", "avatar"]) ??
    coerceString(tweet, ["author_avatar_url"]);
  const sourceAccountID =
    coerceString(author, ["id", "userId", "rest_id"]) ??
    coerceString(tweet, ["author_id", "user_id"]);
  const body =
    coerceString(tweet, ["text", "full_text", "tweet", "content"]) ?? "";
  const publishedAt =
    coerceDate(tweet, ["createdAt", "created_at", "tweet_created_at", "date"]) ??
    nowISO;

  const metrics: Record<string, unknown> = {};
  const replyCount = coerceNumber(tweet, ["replyCount", "reply_count", "replies"]);
  const repostCount = coerceNumber(tweet, ["retweetCount", "retweet_count", "reposts"]);
  const likeCount = coerceNumber(tweet, ["likeCount", "favorite_count", "likes"]);
  const quoteCount = coerceNumber(tweet, ["quoteCount", "quote_count", "quotes"]);
  const viewCount = coerceNumber(tweet, ["viewCount", "views", "impression_count"]);
  if (replyCount != null) metrics.reply_count = replyCount;
  if (repostCount != null) metrics.repost_count = repostCount;
  if (likeCount != null) metrics.like_count = likeCount;
  if (quoteCount != null) metrics.quote_count = quoteCount;
  if (viewCount != null) metrics.view_count = viewCount;

  const safeAuthorHandle = authorHandle ? cleanHandle(authorHandle) : sourceHandle;
  const canonicalURL =
    coerceString(tweet, ["url", "tweet_url", "link"]) ??
    `https://x.com/${safeAuthorHandle}/status/${id}`;

  return {
    provider: "twitterapi.io",
    provider_post_id: id,
    source_handle: sourceHandle,
    source_account_id: sourceAccountID,
    author_handle: authorHandle ? cleanHandle(authorHandle) : null,
    author_name: authorName,
    author_avatar_url: authorAvatarURL,
    body,
    canonical_url: canonicalURL,
    media_urls: extractMediaURLs(tweet),
    metrics,
    published_at: publishedAt,
    fetched_at: nowISO,
    synced_at: nowISO,
    raw_payload: tweet,
    updated_at: nowISO,
  };
}

async function fetchTweetsForHandle(
  handle: string,
  perHandleLimit: number,
  apiKey: string,
): Promise<Record<string, unknown>[]> {
  const url = new URL(
    Deno.env.get("TWITTERAPI_IO_TIMELINE_ENDPOINT") ??
      "https://api.twitterapi.io/twitter/user/last_tweets",
  );
  url.searchParams.set("userName", handle);
  url.searchParams.set("count", String(perHandleLimit));

  const response = await fetch(url, {
    headers: {
      "X-API-Key": apiKey,
      Accept: "application/json",
    },
  });

  if (!response.ok) {
    const text = await response.text();
    throw new Error(
      `twitterapi.io request failed for @${handle}: ${response.status} ${response.statusText} ${text.slice(0, 300)}`,
    );
  }

  const payload = (await response.json()) as ProviderResponse;
  return extractTweetArray(payload);
}

function requireEnv(name: string): string {
  const value = Deno.env.get(name)?.trim();
  if (!value) throw new Error(`Missing required env: ${name}`);
  return value;
}

function validateRequestSecret(request: Request) {
  const expected = Deno.env.get("SYNC_TWEETS_WEBHOOK_SECRET")?.trim();
  if (!expected) return;

  const headerSecret =
    request.headers.get("x-sync-secret")?.trim() ??
    request.headers.get("x-cron-secret")?.trim();
  if (headerSecret !== expected) {
    throw new Error("Unauthorized: invalid sync secret");
  }
}

Deno.serve(async (request) => {
  const requestID = crypto.randomUUID();

  if (request.method === "GET") {
    return json({
      ok: true,
      function: "syncTweets",
      requestId: requestID,
      message:
        "Use POST to sync allowlisted handles into public.tweets_cache. Requires Supabase + twitterapi.io secrets in function env.",
    });
  }

  if (request.method !== "POST") {
    return json({ ok: false, error: "Method not allowed", requestId: requestID }, 405);
  }

  try {
    validateRequestSecret(request);

    const supabaseUrl = requireEnv("SUPABASE_URL");
    const serviceRoleKey = requireEnv("SUPABASE_SERVICE_ROLE_KEY");
    const twitterAPIKey = requireEnv("TWITTERAPI_IO_API_KEY");
    const allowedHandles = parseAllowedHandles(
      Deno.env.get("TWITTER_SYNC_ALLOWED_HANDLES"),
    );
    const sourceFilterHandles = parseAllowedHandles(
      Deno.env.get("TWITTER_SYNC_SOURCE_FILTER_HANDLES"),
    );
    const combinedAllowedHandles = new Set([
      ...allowedHandles,
      ...sourceFilterHandles,
    ]);
    const defaultPerHandleLimit = parsePositiveIntEnv("TWITTER_SYNC_DEFAULT_PER_HANDLE_LIMIT") ?? 10;
    const maxPerHandleLimit = parsePositiveIntEnv("TWITTER_SYNC_MAX_PER_HANDLE_LIMIT") ?? 20;
    const defaultMaxHandlesPerRun = parsePositiveIntEnv("TWITTER_SYNC_DEFAULT_MAX_HANDLES_PER_RUN") ?? 6;
    const maxHandlesPerRunCap = parsePositiveIntEnv("TWITTER_SYNC_MAX_HANDLES_PER_RUN_CAP") ?? 20;
    const defaultMaxTotalTweetsPerRun = parsePositiveIntEnv("TWITTER_SYNC_DEFAULT_MAX_TOTAL_TWEETS_PER_RUN") ?? 60;
    const maxTotalTweetsPerRunCap = parsePositiveIntEnv("TWITTER_SYNC_MAX_TOTAL_TWEETS_PER_RUN_CAP") ?? 200;

    const body = ((await request.json().catch(() => ({}))) ?? {}) as SyncRequest;
    const requestedHandles = (body.handles ?? [])
      .map(cleanHandle)
      .filter((value) => value.length > 0);
    const handles = (requestedHandles.length > 0
      ? requestedHandles
      : Array.from(combinedAllowedHandles)).filter((value, index, array) =>
        array.indexOf(value) === index
      );

    if (handles.length === 0) {
      return json({
        ok: false,
        requestId: requestID,
        error:
          "No handles provided. Send body.handles or configure TWITTER_SYNC_ALLOWED_HANDLES.",
      }, 400);
    }

    if (combinedAllowedHandles.size > 0) {
      const unauthorized = handles.filter((handle) => !combinedAllowedHandles.has(handle));
      if (unauthorized.length > 0) {
        return json({
          ok: false,
          requestId: requestID,
          error: "Handle not allowlisted",
          unauthorized,
        }, 403);
      }
    }

    const maxHandles = clamp(
      body.maxHandles ?? defaultMaxHandlesPerRun,
      1,
      maxHandlesPerRunCap,
    );
    const selectedHandles = handles.slice(0, maxHandles);
    const skippedHandles = handles.slice(maxHandles);
    const perHandleLimit = clamp(body.perHandleLimit ?? defaultPerHandleLimit, 1, maxPerHandleLimit);
    const maxTotalTweets = clamp(
      body.maxTotalTweets ?? defaultMaxTotalTweetsPerRun,
      1,
      maxTotalTweetsPerRunCap,
    );
    const nowISO = new Date().toISOString();
    const normalizedRows: NormalizedTweet[] = [];
    const dedupeKeys = new Set<string>();
    const fetchStats: Array<{ handle: string; fetched: number; normalized: number }> = [];
    let totalFetched = 0;
    let budgetStopped = false;

    for (const handle of selectedHandles) {
      if (normalizedRows.length >= maxTotalTweets) {
        budgetStopped = true;
        break;
      }
      const remainingBudget = Math.max(maxTotalTweets - normalizedRows.length, 1);
      const requestCount = Math.min(perHandleLimit, remainingBudget);
      const rawTweets = await fetchTweetsForHandle(handle, requestCount, twitterAPIKey);
      let normalizedCount = 0;
      totalFetched += rawTweets.length;
      for (const rawTweet of rawTweets) {
        if (normalizedRows.length >= maxTotalTweets) {
          budgetStopped = true;
          break;
        }
        const normalized = normalizeTweet(rawTweet, handle, nowISO);
        if (!normalized) continue;
        const dedupeKey = `${normalized.provider}:${normalized.provider_post_id}`;
        if (dedupeKeys.has(dedupeKey)) continue;
        dedupeKeys.add(dedupeKey);
        normalizedRows.push(normalized);
        normalizedCount += 1;
      }
      fetchStats.push({
        handle,
        fetched: rawTweets.length,
        normalized: normalizedCount,
      });
    }

    if (body.dryRun == true) {
      return json({
        ok: true,
        requestId: requestID,
        dryRun: true,
        handles: selectedHandles,
        skippedHandles,
        perHandleLimit,
        maxHandles,
        maxTotalTweets,
        budgetStopped,
        stats: fetchStats,
        totalFetched,
        wouldUpsert: normalizedRows.length,
      });
    }

    const supabase = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    if (normalizedRows.length > 0) {
      const { error } = await supabase
        .from("tweets_cache")
        .upsert(normalizedRows, { onConflict: "provider,provider_post_id" });
      if (error) {
        throw new Error(`Supabase upsert failed: ${error.message}`);
      }
    }

    return json({
      ok: true,
      requestId: requestID,
      handles: selectedHandles,
      skippedHandles,
      perHandleLimit,
      maxHandles,
      maxTotalTweets,
      budgetStopped,
      stats: fetchStats,
      totalFetched,
      upserted: normalizedRows.length,
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    return json({ ok: false, requestId: requestID, error: message }, 500);
  }
});
