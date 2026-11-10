begin;

alter table public.quests add column nearby jsonb;
create table public.nearby_offers (
  id uuid primary key, owner_id uuid not null references public.profiles on delete cascade,
  draft_id uuid not null, mode text not null check(mode in ('solo','group')),
  title text not null check(char_length(title) between 2 and 80),
  prompt text not null check(char_length(prompt) between 10 and 350),
  nearby jsonb not null check(jsonb_typeof(nearby)='object'), expires_at timestamptz not null
);
create index nearby_offer_expiry on public.nearby_offers(expires_at);
alter table public.nearby_offers enable row level security;
revoke all on public.nearby_offers from public, anon, authenticated;
grant select, insert on public.nearby_offers to service_role;

-- Expired offers can never be redeemed. Collect their temporary listing
-- snapshots on the next batch write without requiring a scheduled job.
create function public.prune_nearby_offers() returns trigger language plpgsql security definer set search_path='' as $$
begin
  delete from public.nearby_offers where expires_at <= now();
  return null;
end $$;
revoke all on function public.prune_nearby_offers() from public,anon,authenticated;
create trigger prune_nearby_offers after insert on public.nearby_offers
  for each statement execute function public.prune_nearby_offers();

-- Use the normal membership and three-task transaction. Replace only its
-- place task using a server-issued offer scoped to this owner, draft and mode.
create function public.start_nearby_memory_space(gid uuid, mode text, space_name text, companions uuid[], offer_id uuid)
returns uuid language plpgsql security definer set search_path='' as $$
declare offer public.nearby_offers; assigned integer;
begin
  if auth.uid() is null or gid is null then raise exception 'Sign in to start a memory.'; end if;
  perform pg_advisory_xact_lock(hashtextextended(gid::text,0));
  if exists(select 1 from public.groups g where g.id=gid and g.created_by=auth.uid() and g.memory_mode is not null)
    then return gid; end if;
  select o.* into offer from public.nearby_offers o where o.id=offer_id and o.owner_id=auth.uid()
    and o.mode=$2 and o.draft_id=gid and o.expires_at>clock_timestamp() for update;
  if not found then raise exception 'This suggestion expired. Find suggestions again.'; end if;
  perform public.start_memory_space(gid,mode,space_name,companions,'anywhere',null);
  update public.quests q set title=offer.title,prompt=offer.prompt,minutes=10,setting='anywhere',nearby=offer.nearby
    where q.group_id=gid and exists(select 1 from public.memory_prompt_catalog c
      where c.family='place' and c.title=q.title and c.context='anywhere');
  get diagnostics assigned=row_count;
  if assigned<>1 then raise exception 'Could not assign the nearby task.'; end if;
  delete from public.nearby_offers o where o.draft_id=gid and o.owner_id=auth.uid();
  return gid;
end $$;
revoke all on function public.start_nearby_memory_space(uuid,text,text,uuid[],uuid) from public,anon;
grant execute on function public.start_nearby_memory_space(uuid,text,text,uuid[],uuid) to authenticated;
commit;
