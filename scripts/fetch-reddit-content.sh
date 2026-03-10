#!/usr/bin/env bash
set -euo pipefail

# Reddit Content Fetcher — runs locally on a schedule
# Fetches hot posts from Reddit for each bot source and inserts into Supabase.
# Your residential IP is not blocked by Reddit (unlike datacenter IPs).

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="$SCRIPT_DIR/../logs/fetch-reddit.log"
mkdir -p "$(dirname "$LOG_FILE")"

SUPABASE_URL="https://lvapccwqypcvhijmevbh.supabase.co"
SUPABASE_SERVICE_ROLE_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imx2YXBjY3dxeXBjdmhpam1ldmJoIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MTczODYxMSwiZXhwIjoyMDg3MzE0NjExfQ.MPZ25x9ZDxgIG2jKdv1HrhV4I7jPsSFA_8DKORH8zdo"

REDDIT_USER_AGENT="PatchNotes/1.0 (Local Bot Content Pipeline)"
MIN_SCORE=10
POSTS_PER_SUBREDDIT=5

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"; }

supabase_get() {
  local table="$1" params="$2"
  curl -s "${SUPABASE_URL}/rest/v1/${table}?${params}" \
    -H "apikey: ${SUPABASE_SERVICE_ROLE_KEY}" \
    -H "Authorization: Bearer ${SUPABASE_SERVICE_ROLE_KEY}"
}

supabase_post() {
  local table="$1" body="$2"
  curl -s "${SUPABASE_URL}/rest/v1/${table}" \
    -X POST \
    -H "apikey: ${SUPABASE_SERVICE_ROLE_KEY}" \
    -H "Authorization: Bearer ${SUPABASE_SERVICE_ROLE_KEY}" \
    -H "Content-Type: application/json" \
    -H "Prefer: return=representation" \
    -d "$body"
}

supabase_patch() {
  local table="$1" params="$2" body="$3"
  curl -s "${SUPABASE_URL}/rest/v1/${table}?${params}" \
    -X PATCH \
    -H "apikey: ${SUPABASE_SERVICE_ROLE_KEY}" \
    -H "Authorization: Bearer ${SUPABASE_SERVICE_ROLE_KEY}" \
    -H "Content-Type: application/json" \
    -d "$body"
}

fetch_subreddit_hot() {
  local subreddit="$1"
  curl -s -H "User-Agent: ${REDDIT_USER_AGENT}" \
    "https://www.reddit.com/r/${subreddit}/hot.json?limit=$((POSTS_PER_SUBREDDIT * 2))&raw_json=1"
}

log "=== Starting Reddit content fetch ==="

# Get active bot sources
sources_json=$(supabase_get "bot_content_sources" "source_type=eq.reddit&is_active=eq.true&select=id,bot_user_id,source_type,source_identifier,game_id,last_fetched_at")
source_count=$(echo "$sources_json" | python3 -c "import json,sys; print(len(json.load(sys.stdin)))" 2>/dev/null || echo "0")
log "Found ${source_count} active Reddit bot sources"

total_created=0
total_skipped=0
total_fetched=0

# Process each source
echo "$sources_json" | python3 -c "
import json, sys, subprocess, time, os

sources = json.load(sys.stdin)
SUPABASE_URL = '${SUPABASE_URL}'
SERVICE_KEY = '${SUPABASE_SERVICE_ROLE_KEY}'
REDDIT_UA = '${REDDIT_USER_AGENT}'
MIN_SCORE = ${MIN_SCORE}
POSTS_PER_SUB = ${POSTS_PER_SUBREDDIT}

headers_sb = {
    'apikey': SERVICE_KEY,
    'Authorization': f'Bearer {SERVICE_KEY}',
    'Content-Type': 'application/json',
    'Prefer': 'return=representation'
}

import urllib.request, urllib.error

def sb_get(table, params=''):
    req = urllib.request.Request(f'{SUPABASE_URL}/rest/v1/{table}?{params}', headers=headers_sb)
    try:
        with urllib.request.urlopen(req) as resp:
            return json.loads(resp.read())
    except Exception as e:
        print(f'  SB GET error: {e}')
        return []

def sb_post(table, data):
    body = json.dumps(data).encode()
    req = urllib.request.Request(f'{SUPABASE_URL}/rest/v1/{table}', data=body, headers=headers_sb, method='POST')
    with urllib.request.urlopen(req) as resp:
        return json.loads(resp.read())

def sb_patch(table, params, data):
    body = json.dumps(data).encode()
    req = urllib.request.Request(f'{SUPABASE_URL}/rest/v1/{table}?{params}', data=body, headers=headers_sb, method='PATCH')
    urllib.request.urlopen(req)

def fetch_reddit(subreddit):
    url = f'https://www.reddit.com/r/{subreddit}/hot.json?limit={POSTS_PER_SUB * 2}&raw_json=1'
    req = urllib.request.Request(url, headers={'User-Agent': REDDIT_UA})
    try:
        with urllib.request.urlopen(req) as resp:
            data = json.loads(resp.read())
            posts = [c['data'] for c in data.get('data', {}).get('children', [])]
            posts = [p for p in posts if not p.get('is_self') or len(p.get('selftext', '')) > 20]
            posts = [p for p in posts if p.get('score', 0) >= MIN_SCORE]
            return posts[:POSTS_PER_SUB]
    except urllib.error.HTTPError as e:
        print(f'  Reddit error r/{subreddit}: {e.code}')
        return []
    except Exception as e:
        print(f'  Reddit error r/{subreddit}: {e}')
        return []

def extract_media(post):
    preview = post.get('preview', {})
    images = preview.get('images', [])
    if images and images[0].get('source', {}).get('url'):
        return images[0]['source']['url']
    thumb = post.get('thumbnail', '')
    if thumb.startswith('http') and 'self' not in thumb and 'default' not in thumb:
        return thumb
    import re
    if re.search(r'\.(jpg|jpeg|png|gif|webp)(\?|$)', post.get('url', ''), re.I):
        return post['url']
    return None

from datetime import datetime, timezone

total_created = 0
total_skipped = 0
total_fetched = 0

for source in sources:
    subreddit = source['source_identifier']
    bot_user_id = source['bot_user_id']
    game_id = source.get('game_id')

    posts = fetch_reddit(subreddit)
    total_fetched += len(posts)
    if posts:
        print(f'  r/{subreddit}: {len(posts)} qualifying posts')

    for post in posts:
        ext_id = f\"reddit_{post['id']}\"

        existing = sb_get('bot_post_log', f'source_external_id=eq.{ext_id}&select=id&limit=1')
        if existing:
            total_skipped += 1
            continue

        media_url = extract_media(post)
        body_text = None
        if post.get('is_self'):
            body_text = post.get('selftext', '')[:2000]
        elif post.get('url') and not media_url:
            body_text = post['url']

        thumb = post.get('thumbnail', '')
        app_post = {
            'author_id': bot_user_id,
            'game_id': game_id,
            'type': 'image' if media_url else 'news',
            'title': post['title'][:300],
            'body': body_text,
            'media_url': media_url,
            'thumbnail_url': thumb if thumb.startswith('http') else None,
            'is_system_generated': True,
            'source_kind': 'bot',
            'source_provider': 'reddit',
            'source_external_id': ext_id,
            'source_handle': f\"r/{post['subreddit']}\",
            'source_url': f\"https://reddit.com{post['permalink']}\",
            'source_published_at': datetime.fromtimestamp(post['created_utc'], tz=timezone.utc).isoformat(),
            'source_metadata': {
                'reddit_score': post.get('score'),
                'reddit_comments': post.get('num_comments'),
                'reddit_author': post.get('author'),
                'reddit_flair': post.get('link_flair_text'),
                'reddit_domain': post.get('domain')
            }
        }

        try:
            result = sb_post('posts', app_post)
            post_id = result[0]['id'] if isinstance(result, list) else result.get('id')

            sb_post('bot_post_log', {
                'bot_user_id': bot_user_id,
                'source_type': 'reddit',
                'source_external_id': ext_id,
                'post_id': post_id
            })
            total_created += 1
        except Exception as e:
            print(f'  Insert error: {e}')

    # Update last_fetched_at
    try:
        sb_patch('bot_content_sources', f'id=eq.{source[\"id\"]}', {'last_fetched_at': datetime.now(tz=timezone.utc).isoformat()})
    except:
        pass

    time.sleep(1)  # Be polite to Reddit

print(f'')
print(f'Results:')
print(f'  Sources processed: {len(sources)}')
print(f'  Posts fetched: {total_fetched}')
print(f'  Posts created: {total_created}')
print(f'  Posts skipped (dedup): {total_skipped}')
" 2>&1 | tee -a "$LOG_FILE"

log "=== Fetch complete ==="
