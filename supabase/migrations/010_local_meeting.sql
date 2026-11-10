begin;
-- Create the group and attach its chosen public map feature to the place
-- assignment atomically. A retried creation keeps the original meeting spot.
create function public.start_local_meeting(gid uuid, space_name text, companions uuid[], spot_name text, osm_id text)
returns uuid language plpgsql security definer set search_path='' as $$
declare band text;
begin
  if auth.uid() is null or gid is null then raise exception 'Sign in to create a group.'; end if;
  perform pg_advisory_xact_lock(hashtextextended(gid::text,0));
  if exists(select 1 from public.groups where id=gid and created_by=auth.uid() and memory_mode='group') then return gid; end if;
  if osm_id is null or osm_id !~ '^(node|way|relation):[1-9][0-9]{0,18}$' or spot_name is null or
    length(trim(spot_name)) not between 1 and 80 or spot_name ~ '[[:cntrl:]]' then raise exception 'Choose a named map feature.'; end if;
  band := public.group_profile_range(companions);
  perform set_config('memorygram.quest_age',case when band='All ages' then '' else band end,true);
  perform public.start_memory_space(gid,'group',space_name,companions,'locality',spot_name);
  update public.quests q set nearby=jsonb_build_object('origin','OpenStreetMap','meeting',trim(spot_name),'osmId',osm_id)
    where q.group_id=gid and exists(select 1 from public.memory_prompt_catalog c where c.context='locality' and c.title=q.title);
  if not found then raise exception 'Could not attach the meeting spot.'; end if;
  return gid;
end $$;
revoke all on function public.start_local_meeting(uuid,text,uuid[],text,text) from public,anon;
grant execute on function public.start_local_meeting(uuid,text,uuid[],text,text) to authenticated;
commit;
