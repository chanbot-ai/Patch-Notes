-- ============================================================
-- Step 1.2: Reddit content cron schedule (30-min cadence)
-- ============================================================
-- Mirrors the syncTweets cron pattern from 20260226151000.

do $$
declare
    has_cron boolean := to_regnamespace('cron') is not null;
    has_net  boolean := to_regnamespace('net')  is not null;
    project_url text := nullif(current_setting('app.settings.supabase_url', true), '');
begin
    if not has_cron then
        raise notice 'Skipping Reddit cron: cron extension unavailable.';
        return;
    end if;

    -- Idempotent: remove existing job if present
    begin
        perform cron.unschedule(jobid)
        from cron.job
        where jobname = 'fetch_reddit_content_30m';
    exception when undefined_table then null;
    end;

    if not has_net then
        raise notice 'Skipping Reddit cron: net extension unavailable.';
        return;
    end if;

    if project_url is null then
        raise notice 'Skipping Reddit cron: supabase_url not set.';
        return;
    end if;

    perform cron.schedule(
        'fetch_reddit_content_30m',
        '*/30 * * * *',
        format(
            $sql$
            select net.http_post(
                url   := %L,
                headers := jsonb_strip_nulls(jsonb_build_object(
                    'content-type',  'application/json',
                    'Authorization', 'Bearer ' || coalesce(
                        nullif(current_setting('app.settings.supabase_anon_key', true), ''), ''
                    ),
                    'apikey', coalesce(
                        nullif(current_setting('app.settings.supabase_anon_key', true), ''), ''
                    ),
                    'x-cron-secret', nullif(current_setting('app.settings.fetch_reddit_webhook_secret', true), '')
                )),
                body  := jsonb_build_object('dryRun', false)
            );
            $sql$,
            rtrim(project_url, '/') || '/functions/v1/fetchRedditContent'
        )
    );

    raise notice 'Reddit content cron scheduled: fetch_reddit_content_30m (*/30 * * * *)';
end;
$$;
