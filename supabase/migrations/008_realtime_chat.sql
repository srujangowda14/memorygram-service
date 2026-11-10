-- Only committed chat inserts are subscribed to by the app. Supabase Realtime
-- authorizes each recipient using the existing space_messages SELECT policy.
do $$
begin
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime'
                 and schemaname = 'public' and tablename = 'space_messages') then
    alter publication supabase_realtime add table public.space_messages;
  end if;
end;
$$;
