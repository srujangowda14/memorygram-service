begin;

alter table public.profiles add column is_private boolean not null default true;
alter table public.memories add column profile_post boolean not null default false,
  add column quest_title text;

create table public.follows (
  follower uuid references public.profiles on delete cascade,
  target uuid references public.profiles on delete cascade,
  status text not null check (status in ('pending', 'accepted')),
  primary key (follower, target), check (follower <> target)
);
create index follows_target on public.follows (target, status);
create table public.memory_people (
  memory_id uuid references public.memories on delete cascade,
  person_id uuid references public.profiles on delete cascade,
  primary key (memory_id, person_id)
);
create index memory_people_person on public.memory_people (person_id, memory_id);
create index memories_photo on public.memories (image_path);
alter table public.follows enable row level security;
alter table public.memory_people enable row level security;
-- Keep older memories accessible to their original group. Only new posts
-- participate in social sharing, so a public profile cannot expose old photos.
insert into public.memory_people select id, author_id from public.memories;

-- Resolve visibility for the current signed-in viewer. This predicate is
-- shared by the memory, participant and storage policies.
create function public.may_read_memory(mid uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select auth.uid() is not null and exists (
    select 1 from public.memories m where m.id = mid and (
      (not m.profile_post and public.is_member(m.group_id)) or
      (m.profile_post and (
        exists (select 1 from public.memory_people x where x.memory_id = mid and x.person_id = auth.uid())
        or (exists (select 1 from public.memory_people x where x.memory_id = mid)
          and not exists (
            select 1 from public.memory_people x join public.profiles p on p.id = x.person_id
            where x.memory_id = mid and p.is_private and not exists (
              select 1 from public.follows f where f.follower = auth.uid()
                and f.target = p.id and f.status = 'accepted'
            )
          ))
      ))
    )
  )
$$;
revoke all on function public.may_read_memory(uuid) from public, anon;
grant execute on function public.may_read_memory(uuid) to authenticated;
drop policy "members read memories" on public.memories;
create policy "read visible memories" on public.memories for select to authenticated using (public.may_read_memory(id));
create policy "read visible participants" on public.memory_people for select to authenticated using (public.may_read_memory(memory_id));
create policy "discover people" on public.profiles for select to authenticated using (true);
-- All new writes pass through publish_memory, which snapshots participants.
drop policy "members add memories" on public.memories;
drop policy "users read group proof" on storage.objects;
create policy "read visible photos" on storage.objects for select to authenticated using (
  bucket_id = 'memory-photos' and ((storage.foldername(name))[1] = auth.uid()::text or exists (
    select 1 from public.memories m where m.image_path = storage.objects.name
      and m.author_id::text = (storage.foldername(storage.objects.name))[1]
  ))
);

-- Return discoverable names, counts and viewer-relative follow state.
-- Private social lists require approval, and incoming requests are owner-only.
create function public.profile_people(kind text, owner_id uuid, search_text text default '', skip_rows integer default 0)
returns table (id uuid, display_name text, is_private boolean, followers bigint, following bigint,
  relation text, follows_me boolean)
language sql stable security definer set search_path = '' as $$
  select p.id, p.display_name, p.is_private,
    (select count(*) from public.follows f where f.target = p.id and f.status = 'accepted'),
    (select count(*) from public.follows f where f.follower = p.id and f.status = 'accepted'),
    coalesce(outgoing.status, 'none'), coalesce(incoming.status = 'accepted', false)
  from public.profiles p
  left join public.follows outgoing on outgoing.target = p.id and outgoing.follower = auth.uid()
  left join public.follows incoming on incoming.follower = p.id and incoming.target = auth.uid()
  where auth.uid() is not null and position(lower(coalesce(search_text,'')) in lower(p.display_name)) > 0
    and case kind
      when 'profile' then p.id = owner_id
      when 'discover' then p.id <> auth.uid()
      when 'friends' then outgoing.status = 'accepted' and incoming.status = 'accepted'
      when 'requests' then owner_id = auth.uid() and incoming.status = 'pending'
      when 'followers' then exists (select 1 from public.follows f where f.follower = p.id and f.target = owner_id and f.status = 'accepted')
      when 'following' then exists (select 1 from public.follows f where f.target = p.id and f.follower = owner_id and f.status = 'accepted')
      else false end
    and (kind not in ('followers','following') or owner_id = auth.uid() or exists (
      select 1 from public.profiles target where target.id = owner_id and (not target.is_private or exists (
        select 1 from public.follows f where f.target = owner_id and f.follower = auth.uid() and f.status = 'accepted'
      ))
    ))
  order by p.display_name, p.id offset greatest(skip_rows, 0) limit 30
$$;

-- Only the target may approve incoming requests. Lock its profile during
-- follow and privacy changes so concurrent requests respect the chosen setting.
create function public.change_follow(person uuid, action text) returns void
language plpgsql security definer set search_path = '' as $$
declare me uuid := auth.uid(); private_target boolean;
begin
  if me is null or me = person then raise exception 'Choose another person.'; end if;
  case action
    when 'follow' then
      select is_private into strict private_target from public.profiles where id = person for update;
      insert into public.follows values (me, person, case when private_target then 'pending' else 'accepted' end)
        on conflict do nothing;
    when 'unfollow' then delete from public.follows where follower = me and target = person;
    when 'approve' then update public.follows set status = 'accepted' where follower = person and target = me and status = 'pending';
    when 'decline' then delete from public.follows where follower = person and target = me and status = 'pending';
    when 'remove' then delete from public.follows where follower = person and target = me and status = 'accepted';
    else raise exception 'Unknown follow action.';
  end case;
end $$;

-- Update the current person's privacy. Going public also accepts pending
-- requests, which otherwise could stay pending on an open profile.
create function public.set_profile_privacy(private_profile boolean) returns void
language plpgsql security definer set search_path = '' as $$
begin
  update public.profiles set is_private = private_profile where id = auth.uid();
  if not found then raise exception 'Profile unavailable.'; end if;
  if not private_profile then
    update public.follows set status = 'accepted' where target = auth.uid() and status = 'pending';
  end if;
end $$;

-- One transaction creates the group, memory and immutable participant list.
-- The client-generated memory ID makes a retry after a lost response safe.
create function public.publish_memory(mid uuid, caption_text text, quest_name text, group_name text, companions uuid[])
returns uuid language plpgsql security definer set search_path = '' as $$
declare me uuid := auth.uid(); gid uuid; ids uuid[]; photo text := me::text || '/' || mid::text;
begin
  if me is null or mid is null then raise exception 'Sign in to post.'; end if;
  perform pg_advisory_xact_lock(hashtextextended(mid::text,0));
  if exists (select 1 from public.memories where id = mid and author_id = me and profile_post) then return mid; end if;
  select array(select distinct x from unnest(array_append(companions,me)) x) into ids;
  if cardinality(ids) > 20 or exists (
    select 1 from unnest(ids) x where x is null or (x <> me and not exists (
      select 1 from public.follows a join public.follows b on b.target=a.follower and b.follower=a.target
      where a.follower = me and a.target = x and a.status = 'accepted' and b.status = 'accepted'
    ))
  ) then raise exception 'Choose up to 19 people who follow you back.'; end if;
  if char_length(trim(quest_name)) > 120 or char_length(trim(caption_text)) not between 1 and 220 then
    raise exception 'Add a caption of up to 220 characters.';
  end if;
  if not exists (select 1 from storage.objects where bucket_id='memory-photos' and name=photo) then
    raise exception 'Upload the photo first.'; end if;
  insert into public.groups(name,created_by) values (coalesce(nullif(trim(group_name),''),'Memory group'),me) returning id into gid;
  insert into public.group_members(group_id,user_id,role) select gid,x,case when x=me then 'owner' else 'member' end from unnest(ids) x;
  insert into public.memories(id,group_id,author_id,caption,image_path,quest_title,profile_post)
    values(mid,gid,me,trim(caption_text),photo,trim(quest_name),true);
  insert into public.memory_people select mid,x from unnest(ids) x;
  return mid;
end $$;

revoke all on function public.profile_people(text,uuid,text,integer), public.change_follow(uuid,text),
  public.set_profile_privacy(boolean), public.publish_memory(uuid,text,text,text,uuid[]) from public, anon;
grant execute on function public.profile_people(text,uuid,text,integer), public.change_follow(uuid,text),
  public.set_profile_privacy(boolean), public.publish_memory(uuid,text,text,text,uuid[]) to authenticated;
grant select on public.memory_people, public.profiles, public.memories to authenticated;
commit;
