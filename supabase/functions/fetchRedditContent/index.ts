import { createClient } from "npm:@supabase/supabase-js@2";

// ============================================================
// Reddit Content Sourcing Edge Function
// Fetches top posts from mapped subreddits and creates bot posts
// ============================================================

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

interface BotSource {
  id: string;
  bot_user_id: string;
  source_type: string;
  source_identifier: string; // subreddit name
  game_id: string | null;
  last_fetched_at: string | null;
}

const REDDIT_USER_AGENT = "PatchNotes/1.0 (Bot Content Pipeline)";
const MIN_SCORE = 10; // Minimum upvotes to consider
const POSTS_PER_SUBREDDIT = 5;

async function fetchSubredditHot(subreddit: string): Promise<RedditPost[]> {
  // Use oauth.reddit.com if we have credentials, otherwise old.reddit.com
  // (www.reddit.com blocks datacenter IPs like Supabase edge)
  const accessToken = Deno.env.get("REDDIT_ACCESS_TOKEN");
  const url = accessToken
    ? `https://oauth.reddit.com/r/${subreddit}/hot?limit=${POSTS_PER_SUBREDDIT * 2}&raw_json=1`
    : `https://old.reddit.com/r/${subreddit}/hot.json?limit=${POSTS_PER_SUBREDDIT * 2}&raw_json=1`;
  const headers: Record<string, string> = { "User-Agent": REDDIT_USER_AGENT };
  if (accessToken) {
    headers["Authorization"] = `Bearer ${accessToken}`;
  }
  const resp = await fetch(url, { headers });

  if (!resp.ok) {
    console.error(`Reddit API error for r/${subreddit}: ${resp.status} ${resp.statusText}`);
    return [];
  }

  const data = await resp.json();
  const posts: RedditPost[] = (data?.data?.children ?? [])
    .map((child: { data: RedditPost }) => child.data)
    .filter(
      (post: RedditPost) =>
        !post.is_self || post.selftext.length > 20, // Skip empty self posts
    )
    .filter((post: RedditPost) => post.score >= MIN_SCORE)
    .slice(0, POSTS_PER_SUBREDDIT);

  return posts;
}

function extractMediaUrl(post: RedditPost): string | null {
  // Try preview image first
  if (post.preview?.images?.[0]?.source?.url) {
    return post.preview.images[0].source.url;
  }
  // Try thumbnail (if it's a real URL)
  if (
    post.thumbnail &&
    post.thumbnail.startsWith("http") &&
    !post.thumbnail.includes("self") &&
    !post.thumbnail.includes("default")
  ) {
    return post.thumbnail;
  }
  // Try the post URL if it's an image
  if (/\.(jpg|jpeg|png|gif|webp)(\?|$)/i.test(post.url)) {
    return post.url;
  }
  return null;
}

function redditPostToAppPost(
  post: RedditPost,
  botUserId: string,
  gameId: string | null,
): {
  author_id: string;
  game_id: string | null;
  type: string;
  title: string;
  body: string | null;
  media_url: string | null;
  thumbnail_url: string | null;
  is_system_generated: boolean;
  source_kind: string;
  source_provider: string;
  source_external_id: string;
  source_handle: string;
  source_url: string;
  source_published_at: string;
  source_metadata: Record<string, unknown>;
} {
  const mediaUrl = extractMediaUrl(post);
  const body = post.is_self
    ? post.selftext.slice(0, 2000)
    : post.url && !mediaUrl
      ? post.url
      : null;

  return {
    author_id: botUserId,
    game_id: gameId,
    type: mediaUrl ? "image" : "news",
    title: post.title.slice(0, 300),
    body: body,
    media_url: mediaUrl,
    thumbnail_url: post.thumbnail?.startsWith("http") ? post.thumbnail : null,
    is_system_generated: true,
    source_kind: "bot",
    source_provider: "reddit",
    source_external_id: `reddit_${post.id}`,
    source_handle: `r/${post.subreddit}`,
    source_url: `https://reddit.com${post.permalink}`,
    source_published_at: new Date(post.created_utc * 1000).toISOString(),
    source_metadata: {
      reddit_score: post.score,
      reddit_comments: post.num_comments,
      reddit_author: post.author,
      reddit_flair: post.link_flair_text ?? null,
      reddit_domain: post.domain,
    },
  };
}

Deno.serve(async (req) => {
  // Cron secret validation (matches syncTweets pattern)
  const cronSecret = Deno.env.get("FETCH_REDDIT_WEBHOOK_SECRET");
  if (cronSecret) {
    const reqSecret = req.headers.get("x-cron-secret");
    if (reqSecret !== cronSecret) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401,
        headers: { "Content-Type": "application/json" },
      });
    }
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const supabase = createClient(supabaseUrl, serviceKey);

    // Parse optional request body
    let limitBots: number | undefined;
    let dryRun = false;
    try {
      const body = await req.json();
      limitBots = body?.limitBots;
      dryRun = body?.dryRun ?? false;
    } catch {
      // No body, use defaults
    }

    // 1. Fetch active bot content sources
    let query = supabase
      .from("bot_content_sources")
      .select("id,bot_user_id,source_type,source_identifier,game_id,last_fetched_at")
      .eq("source_type", "reddit")
      .eq("is_active", true);

    if (limitBots) {
      query = query.limit(limitBots);
    }

    const { data: sources, error: srcError } = await query;
    if (srcError) throw srcError;

    const botSources = sources as BotSource[];
    console.log(`Found ${botSources.length} active Reddit bot sources`);

    let totalCreated = 0;
    let totalSkipped = 0;
    let totalFetched = 0;
    const errors: string[] = [];

    // 2. Process each bot source
    for (const source of botSources) {
      try {
        const posts = await fetchSubredditHot(source.source_identifier);
        totalFetched += posts.length;
        console.log(
          `r/${source.source_identifier}: fetched ${posts.length} qualifying posts`,
        );

        for (const post of posts) {
          const externalId = `reddit_${post.id}`;

          // Check dedup log
          const { data: existing } = await supabase
            .from("bot_post_log")
            .select("id")
            .eq("source_external_id", externalId)
            .maybeSingle();

          if (existing) {
            totalSkipped++;
            continue;
          }

          const appPost = redditPostToAppPost(
            post,
            source.bot_user_id,
            source.game_id,
          );

          if (dryRun) {
            console.log(`[DRY RUN] Would create: "${appPost.title}"`);
            totalCreated++;
            continue;
          }

          // Insert post
          const { data: insertedPost, error: insertError } = await supabase
            .from("posts")
            .insert(appPost)
            .select("id")
            .single();

          if (insertError) {
            console.error(
              `Failed to insert post "${post.title}": ${insertError.message}`,
            );
            errors.push(
              `r/${source.source_identifier}: ${insertError.message}`,
            );
            continue;
          }

          // Log for dedup
          await supabase.from("bot_post_log").insert({
            bot_user_id: source.bot_user_id,
            source_type: "reddit",
            source_external_id: externalId,
            post_id: insertedPost.id,
          });

          totalCreated++;
        }

        // Update last_fetched_at
        await supabase
          .from("bot_content_sources")
          .update({ last_fetched_at: new Date().toISOString() })
          .eq("id", source.id);
      } catch (err) {
        const msg = `r/${source.source_identifier}: ${(err as Error).message}`;
        console.error(msg);
        errors.push(msg);
      }
    }

    return new Response(
      JSON.stringify({
        success: true,
        dryRun,
        sourcesProcessed: botSources.length,
        postsCreated: totalCreated,
        postsSkipped: totalSkipped,
        postsFetchedFromReddit: totalFetched,
        errors,
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
