do $$
declare
    has_cron boolean := to_regnamespace('cron') is not null;
    has_net boolean := to_regnamespace('net') is not null;
    project_url text := nullif(current_setting('app.settings.supabase_url', true), '');
    anon_key text := nullif(current_setting('app.settings.supabase_anon_key', true), '');
    cron_secret text := nullif(current_setting('app.settings.sync_tweets_webhook_secret', true), '');
begin
    if not has_cron then
        raise notice 'Skipping syncTweets cron auth-header reschedule: cron schema/extension is unavailable.';
        return;
    end if;

    if not has_net then
        raise notice 'Skipping syncTweets cron auth-header reschedule: net schema/extension is unavailable.';
        return;
    end if;

    if project_url is null then
        raise notice 'Skipping syncTweets cron auth-header reschedule: app.settings.supabase_url is not set.';
        return;
    end if;

    if anon_key is null then
        raise notice 'Skipping syncTweets cron auth-header reschedule: app.settings.supabase_anon_key is not set.';
        return;
    end if;

    begin
        perform cron.unschedule(jobid)
        from cron.job
        where jobname = 'sync_tweets_cache_30m';
    exception
        when undefined_table then
            null;
    end;

    -- Supabase Edge gateway still requires Authorization/apikey headers even when verify_jwt=false.
    perform cron.schedule(
        'sync_tweets_cache_30m',
        '*/30 * * * *',
        format(
            $sql$
            select net.http_post(
                url := %L,
                headers := jsonb_strip_nulls(jsonb_build_object(
                    'content-type', 'application/json',
                    'authorization', %L,
                    'apikey', %L,
                    'x-cron-secret', %L
                )),
                body := jsonb_build_object('dryRun', false)
            );
            $sql$,
            rtrim(project_url, '/') || '/functions/v1/syncTweets',
            'Bearer ' || anon_key,
            anon_key,
            cron_secret
        )
    );
end;
$$;
