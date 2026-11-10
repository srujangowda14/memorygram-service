begin;
-- Append a chosen map destination for members of a group. Lock the group
-- so retries and simultaneous selections cannot create duplicate outings.
create function public.add_local_outing(gid uuid, spot_name text, osm_id text) returns void
language plpgsql security definer set search_path='' as $$
begin
  perform 1 from public.groups where id=gid and memory_mode='group' and public.is_member(gid) for update;
  if not found then raise exception 'Group unavailable'; end if;
  if osm_id is null or osm_id !~ '^(node|way|relation):[1-9][0-9]{0,18}$' or spot_name is null or
    length(trim(spot_name)) not between 1 and 80 or spot_name ~ '[[:cntrl:]]' then raise exception 'Choose a named map feature'; end if;
  if exists(select 1 from public.quests where group_id=gid and nearby->>'osmId'=osm_id) then return; end if;
  insert into public.quests(group_id,title,prompt,minutes,setting,people,nearby)
    values(gid,trim(spot_name),'Visit '||trim(spot_name)||' together. Save a photo and each person’s favorite detail from the outing.',
    30,'anywhere','group',jsonb_build_object('origin','OpenStreetMap','meeting',trim(spot_name),'osmId',osm_id));
end $$;
revoke all on function public.add_local_outing(uuid,text,text) from public,anon;
grant execute on function public.add_local_outing(uuid,text,text) to authenticated;
commit;
