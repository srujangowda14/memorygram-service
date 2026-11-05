begin;

create index memories_feed_order on public.memories (created_at desc, id desc) where profile_post;

-- Preserve existing votes as likes. All interaction policies use the same
-- audience check as the photo, including after a follow or privacy change.
drop policy "members read votes" on public.memory_votes;
drop policy "members vote" on public.memory_votes;
drop policy "members remove own vote" on public.memory_votes;
create policy "read memory likes" on public.memory_votes for select to authenticated
  using (public.may_read_memory(memory_id));
create policy "like visible memory" on public.memory_votes for insert to authenticated
  with check (user_id = auth.uid() and public.may_read_memory(memory_id));
create policy "unlike visible memory" on public.memory_votes for delete to authenticated
  using (user_id = auth.uid() and public.may_read_memory(memory_id));

create table public.memory_comments (
  id uuid primary key,
  memory_id uuid not null references public.memories on delete cascade,
  author_id uuid not null references public.profiles on delete cascade default auth.uid(),
  body text not null check (body ~ '[^[:space:]]' and char_length(body) between 1 and 500),
  created_at timestamptz not null default now()
);
create index memory_comments_thread on public.memory_comments (memory_id, created_at desc, id desc);
alter table public.memory_comments enable row level security;
create policy "read visible comments" on public.memory_comments for select to authenticated
  using (public.may_read_memory(memory_id));
create policy "comment on visible memory" on public.memory_comments for insert to authenticated
  with check (author_id = auth.uid() and public.may_read_memory(memory_id));
revoke all on public.memory_comments from public, anon, authenticated;
grant select, insert (id, memory_id, body) on public.memory_comments to authenticated;
grant select, insert, delete on public.memory_votes to authenticated;

-- Supply counts and the viewer's own like state for a page of visible posts.
-- Running as the caller keeps hidden posts, their counts and their IDs private.
create function public.memory_activity(ids uuid[])
returns table(memory_id uuid, likes integer, liked boolean, comments integer)
language sql stable security invoker set search_path = '' as $$
  select m.id,
    (select count(*)::integer from public.memory_votes v where v.memory_id=m.id),
    exists(select 1 from public.memory_votes v where v.memory_id=m.id and v.user_id=auth.uid()),
    (select count(*)::integer from public.memory_comments c where c.memory_id=m.id)
  from public.memories m where m.id=any(ids)
$$;

-- Set a desired state rather than toggling it so retries cannot reverse a like.
-- Return the count after writing, using the same projection as the feed.
create function public.set_memory_like(mid uuid, wanted boolean)
returns table(memory_id uuid, likes integer, liked boolean, comments integer)
language plpgsql security invoker set search_path = '' as $$
begin
  if not public.may_read_memory(mid) then raise exception 'Memory unavailable'; end if;
  if wanted then
    insert into public.memory_votes(memory_id,user_id) values(mid,auth.uid()) on conflict do nothing;
  else
    delete from public.memory_votes v where v.memory_id=mid and v.user_id=auth.uid();
  end if;
  return query select * from public.memory_activity(array[mid]);
end $$;
revoke all on function public.memory_activity(uuid[]), public.set_memory_like(uuid,boolean) from public, anon;
grant execute on function public.memory_activity(uuid[]), public.set_memory_like(uuid,boolean) to authenticated;
commit;
