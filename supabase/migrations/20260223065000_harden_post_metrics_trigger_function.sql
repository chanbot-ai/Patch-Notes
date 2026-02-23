begin;

create or replace function public.create_post_metrics_row()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $function$
begin
  insert into public.post_metrics (post_id)
  values (new.id);
  return new;
end;
$function$;

comment on function public.create_post_metrics_row() is
  'Trigger helper that auto-creates a post_metrics row for new posts. SECURITY DEFINER so app clients do not need direct write access to post_metrics.';

commit;
