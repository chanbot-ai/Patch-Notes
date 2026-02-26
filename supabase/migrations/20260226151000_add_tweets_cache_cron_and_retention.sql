create or replace function public.purge_old_tweets_cache(
    retention interval default interval '30 days',
    batch_limit integer default 5000
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
    deleted_count integer := 0;
begin
    if batch_limit is null or batch_limit < 1 then
        batch_limit := 5000;
    end if;

    with doomed as (
        select id
        from public.tweets_cache
        where coalesce(published_at, synced_at, created_at) < now() - retention
        order by coalesce(published_at, synced_at, created_at) asc
        limit batch_limit
    )
    delete from public.tweets_cache cache
    using doomed
    where cache.id = doomed.id;

    get diagnostics deleted_count = row_count;
    return deleted_count;
end;
$$;

revoke all privileges on function public.purge_old_tweets_cache(interval, integer) from public;
grant execute on function public.purge_old_tweets_cache(interval, integer) to service_role;

comment on function public.purge_old_tweets_cache(interval, integer) is
    'Batch deletes old rows from tweets_cache for retention cleanup cron jobs.';

do $$
declare
    has_cron boolean := to_regnamespace('cron') is not null;
    has_net boolean := to_regnamespace('net') is not null;
    project_url text := nullif(current_setting('app.settings.supabase_url', true), '');
begin
    if not has_cron then
        raise notice 'Skipping tweets cache cron schedules: cron schema/extension is unavailable.';
        return;
    end if;

    -- Idempotent reschedule on repeated migration runs/restores.
    begin
        perform cron.unschedule(jobid)
        from cron.job
        where jobname in ('tweets_cache_retention_daily', 'sync_tweets_cache_30m');
    exception
        when undefined_table then
            null;
    end;

    perform cron.schedule(
        'tweets_cache_retention_daily',
        '15 4 * * *',
        $job$select public.purge_old_tweets_cache(interval '30 days', 5000);$job$
    );

    if not has_net then
        raise notice 'Skipping syncTweets cron schedule: net schema/extension is unavailable.';
        return;
    end if;

    if project_url is null then
        raise notice 'Skipping syncTweets cron schedule: app.settings.supabase_url is not set.';
        return;
    end if;

    perform cron.schedule(
        'sync_tweets_cache_30m',
        '*/30 * * * *',
        format(
            $sql$
            select net.http_post(
                url := %L,
                headers := jsonb_strip_nulls(jsonb_build_object(
                    'content-type', 'application/json',
                    'x-cron-secret', nullif(current_setting('app.settings.sync_tweets_webhook_secret', true), '')
                )),
                body := jsonb_build_object('dryRun', false)
            );
            $sql$,
            rtrim(project_url, '/') || '/functions/v1/syncTweets'
        )
    );
end;
$$;

comment on table public.tweets_cache is
    'Server-synced cache of selected X/Twitter posts (twitterapi.io source) for app-side read-only feed usage. Retention cleanup + cron sync scaffolding added in 20260226151000.';
