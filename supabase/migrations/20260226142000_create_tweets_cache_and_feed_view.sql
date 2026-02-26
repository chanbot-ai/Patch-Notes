create table if not exists public.tweets_cache (
    id uuid primary key default gen_random_uuid(),
    provider text not null default 'twitterapi.io',
    provider_post_id text not null,
    source_handle text not null,
    source_account_id text,
    author_handle text,
    author_name text,
    author_avatar_url text,
    body text not null default '',
    canonical_url text,
    media_urls jsonb not null default '[]'::jsonb,
    metrics jsonb not null default '{}'::jsonb,
    published_at timestamp with time zone not null,
    fetched_at timestamp with time zone not null default now(),
    synced_at timestamp with time zone not null default now(),
    raw_payload jsonb not null default '{}'::jsonb,
    is_hidden boolean not null default false,
    created_at timestamp with time zone not null default now(),
    updated_at timestamp with time zone not null default now(),
    constraint tweets_cache_provider_check
        check (provider in ('twitterapi.io'))
);

create unique index if not exists tweets_cache_provider_provider_post_id_idx
    on public.tweets_cache (provider, provider_post_id);

create index if not exists tweets_cache_source_handle_published_at_idx
    on public.tweets_cache (source_handle, published_at desc);

create index if not exists tweets_cache_published_at_idx
    on public.tweets_cache (published_at desc);

create index if not exists tweets_cache_hidden_published_at_idx
    on public.tweets_cache (is_hidden, published_at desc);

alter table public.tweets_cache enable row level security;

drop policy if exists "Public can read visible tweets cache" on public.tweets_cache;
create policy "Public can read visible tweets cache"
on public.tweets_cache
for select
to anon, authenticated
using (is_hidden = false);

revoke all privileges on table public.tweets_cache from anon;
revoke all privileges on table public.tweets_cache from authenticated;
grant select, insert, update, delete on table public.tweets_cache to service_role;

create or replace view public.tweets_cache_feed_view as
select
    id,
    provider,
    provider_post_id,
    source_handle,
    source_account_id,
    author_handle,
    author_name,
    author_avatar_url,
    body,
    canonical_url,
    media_urls,
    metrics,
    published_at,
    fetched_at,
    synced_at,
    created_at,
    updated_at
from public.tweets_cache
where is_hidden = false
order by published_at desc;

revoke all privileges on table public.tweets_cache_feed_view from anon;
revoke all privileges on table public.tweets_cache_feed_view from authenticated;
grant select on table public.tweets_cache_feed_view to anon, authenticated;

comment on table public.tweets_cache is
    'Server-synced cache of selected X/Twitter posts (twitterapi.io source) for app-side read-only feed usage.';

comment on view public.tweets_cache_feed_view is
    'Client-facing sanitized feed view over tweets_cache without raw provider payloads.';

