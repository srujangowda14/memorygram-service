begin;

alter table public.groups add column memory_mode text check (memory_mode in ('solo','group'));
create index memory_spaces_recent on public.groups(created_at desc, id desc) where memory_mode is not null;
create index group_members_person on public.group_members(user_id,group_id);
create index group_quests on public.quests(group_id);
-- Each new assignment can produce one memory, even if two members finish
-- together. Legacy quest submissions are outside this uniqueness constraint.
alter table public.memories add column space_completion boolean not null default false;
create unique index memory_space_result on public.memories(quest_id) where space_completion;

create table public.space_messages (
  id uuid primary key, group_id uuid not null references public.groups on delete cascade,
  author_id uuid not null references public.profiles default auth.uid(),
  body text not null check (body ~ '[^[:space:]]' and char_length(body) between 1 and 1000),
  created_at timestamptz not null default now()
);
create index space_message_order on public.space_messages(group_id,created_at desc,id desc);
alter table public.space_messages enable row level security;
create policy "read group chat" on public.space_messages for select to authenticated
  using (public.is_member(group_id));
create policy "send to own group chat" on public.space_messages for insert to authenticated
  with check (author_id=auth.uid() and exists (
    select 1 from public.groups g where g.id=group_id and g.memory_mode='group' and public.is_member(g.id)
  ));
revoke all on public.space_messages from public,anon,authenticated;
grant select,insert(id,group_id,body) on public.space_messages to authenticated;
grant select on public.groups, public.group_members, public.quests to authenticated;

-- This catalog is the server's assignment source. The guest bundle contains
-- the same prompts in memorygram-mobile/lib/memory-prompts.json.
create table public.memory_prompt_catalog (
  key text primary key, family text not null, mode text not null, context text not null,
  minutes smallint not null, setting text not null, title text not null, prompt text not null
);
alter table public.memory_prompt_catalog enable row level security;
revoke all on public.memory_prompt_catalog from public, anon, authenticated;
insert into public.memory_prompt_catalog values
  ('desk', 'keepsake', 'solo', 'anywhere', 5, 'anywhere', 'A museum of today', 'Choose one object you touched today. Photograph it and write the label you would want to read in ten years.'),
  ('routine', 'keepsake', 'solo', 'anywhere', 5, 'indoors', 'The usual, please', 'Catch a detail of a daily ritual, like the chipped edge of your mug. Finish the caption with what you would miss about it.'),
  ('song', 'keepsake', 'solo', 'anywhere', 5, 'anywhere', 'A song lives here', 'Think of a song that takes you back. Photograph an object that belongs in that scene and write who or what the song brings to mind.'),
  ('skill', 'discovery', 'solo', 'anywhere', 10, 'anywhere', 'Keep the first draft', 'Give something a first try on scrap paper. Save the crooked sketch, first line or pencil marks and name one thing you figured out.'),
  ('win', 'discovery', 'solo', 'anywhere', 5, 'anywhere', 'Proof of a small win', 'Find a trace of something you can do now that once felt difficult. Take a picture and tell your past self what changed.'),
  ('color', 'discovery', 'solo', 'anywhere', 5, 'anywhere', 'Today''s signature color', 'Pick a color and look for it from where you are. Photograph the most surprising match and give today a paint-swatch name.'),
  ('ritual', 'keepsake', 'group', 'anywhere', 10, 'anywhere', 'Our unofficial tradition', 'Ask what your group always seems to do together. Stage a photo of one detail and write how the tradition began, or your best guesses.'),
  ('joke', 'keepsake', 'group', 'anywhere', 5, 'anywhere', 'The joke in the group chat', 'Choose a phrase that makes everyone laugh. Photograph a prop that explains it and add the line a future friend would need to get the joke.'),
  ('recipe', 'keepsake', 'group', 'anywhere', 10, 'indoors', 'A recipe with a backstory', 'Trade stories of a meal someone made for you. Photograph a utensil or sketch one dish, then save the detail that makes it theirs.'),
  ('angles', 'discovery', 'group', 'anywhere', 5, 'anywhere', 'Same minute, two stories', 'Pause together, in person or on a call. Each name the first detail you noticed. Photograph one and put both impressions in the caption.'),
  ('cheer', 'discovery', 'group', 'anywhere', 5, 'anywhere', 'Make a tiny trophy', 'Let someone volunteer a small win. Ask what it took, build a trophy from things at hand and photograph it with the winner''s words.'),
  ('cover', 'discovery', 'group', 'anywhere', 10, 'anywhere', 'Our debut album', 'Invent a band name for this group. Arrange three objects as the album cover and give the first track a title only your group would understand.'),
  ('postcard', 'place', 'any', 'anywhere', 5, 'anywhere', 'Postcard from right here', 'Frame a familiar spot as a postcard. Photograph a detail a visitor might miss and write a line to someone who would recognize it.'),
  ('sound', 'place', 'any', 'anywhere', 5, 'anywhere', 'Picture the sound', 'Listen for a moment. Photograph what made one sound, or an object it reminds you of. Spell out the sound in the caption.'),
  ('morning', 'place', 'any', 'morning', 5, 'anywhere', 'Before the day gets going', 'Find one sign of the morning where you are, even from your chair. Photograph it and write what the day still has in store.'),
  ('afternoon', 'place', 'any', 'afternoon', 5, 'anywhere', 'The afternoon edition', 'Look for a detail that tells the story of this afternoon. Photograph it and turn the caption into a one-line local headline.'),
  ('evening', 'place', 'any', 'evening', 5, 'indoors', 'The last page of the day', 'Find one object that sums up the day so far. Photograph it where you are and write the closing line you want to remember.'),
  ('crissy', 'place', 'any', 'crissy', 10, 'anywhere', 'A postcard for Crissy Field', 'Near the bay, look for a detail shaped by wind or water. Photograph it from where you are, or sketch a remembered view of Crissy Field.'),
  ('mall', 'place', 'any', 'mall', 10, 'anywhere', 'Beside the Reflecting Pool', 'Look for a reflection near you, in glass, water or a spoon. Photograph it and write a postcard to the National Mall from your side of the reflection.'),
  ('cubbon', 'place', 'any', 'cubbon', 10, 'anywhere', 'Cubbon Park in miniature', 'Look for a leaf shape or branching pattern nearby. Photograph it, or draw it from memory, and give your tiny piece of Bengaluru a name.'),
  ('stamp', 'place', 'any', 'locality', 10, 'anywhere', 'The unofficial postage stamp', 'Design a postage stamp for {place}. Photograph a detail or a little sketch for the stamp and tell the story behind your choice.'),
  ('directions', 'place', 'any', 'locality', 5, 'anywhere', 'Directions only a local would give', 'Think of a landmark you use when describing {place} to someone. Photograph or sketch it, then write your directions in your own words.'),
  ('greeting', 'place', 'any', 'locality', 5, 'anywhere', 'Wish you were here', 'Pick a detail of life around {place} you would send to someone who moved away. Photograph it or draw it and write the first line of your postcard.');

-- Create the room and its three assignments atomically. The caller chooses
-- only the mode, mutual friends and a coarse, explicitly accepted context.
create function public.start_memory_space(gid uuid, mode text, space_name text, companions uuid[], place_context text, locality_name text default null)
returns uuid language plpgsql security definer set search_path = '' as $$
declare me uuid := auth.uid(); friends uuid[]; assigned integer;
begin
  if me is null or gid is null then raise exception 'Sign in to start a memory.'; end if;
  perform pg_advisory_xact_lock(hashtextextended(gid::text,0));
  if exists(select 1 from public.groups g where g.id=gid and g.created_by=me and g.memory_mode is not null) then return gid; end if;
  if place_context='locality' and (locality_name is null or length(trim(locality_name)) not between 1 and 80
    or locality_name ~ '[[:cntrl:]]') then raise exception 'Choose a valid locality.'; end if;
  select array(select distinct x from unnest(companions) x) into friends;
  if mode is null or mode not in ('solo','group') or space_name is null or length(trim(space_name)) not between 2 and 50
    or (mode='solo' and cardinality(friends)<>0) or (mode='group' and cardinality(friends) not between 1 and 19)
    then raise exception 'Choose a name and the people for this space.'; end if;
  if exists(select 1 from unnest(friends) x where x is null or x=me or not exists (
    select 1 from public.follows a join public.follows b on b.follower=a.target and b.target=a.follower
    where a.follower=me and a.target=x and a.status='accepted' and b.status='accepted'
  )) then raise exception 'Choose friends who follow you back.'; end if;
  insert into public.groups(id,name,created_by,memory_mode) values(gid,trim(space_name),me,mode);
  insert into public.group_members(group_id,user_id,role) values(gid,me,'owner');
  insert into public.group_members(group_id,user_id) select gid,x from unnest(friends) x;
  insert into public.quests(group_id,title,prompt,minutes,setting,people)
    select gid,p.title,replace(p.prompt,'{place}',coalesce(trim(locality_name),'')),p.minutes,p.setting,$2 from (
      select distinct on (c.family) c.* from public.memory_prompt_catalog c
      where c.mode in ($2,'any') and c.context in ('anywhere',place_context)
      order by c.family,(c.context=place_context) desc,random()
    ) p;
  get diagnostics assigned=row_count;
  if assigned<>3 then raise exception 'Could not assign three tasks.'; end if;
  return gid;
end $$;

-- Turn a task into a private photo memory for its existing group. Lock the
-- task during completion and recognize a retry after a lost response.
create function public.finish_memory_task(task uuid, mid uuid, caption_text text)
returns uuid language plpgsql security definer set search_path = '' as $$
declare me uuid := auth.uid(); q public.quests; photo text := me::text || '/' || mid::text;
begin
  select t.* into q from public.quests t join public.groups g on g.id=t.group_id
    where t.id=task and g.memory_mode is not null and public.is_member(g.id) for update of t;
  if not found or me is null then raise exception 'Task unavailable.'; end if;
  if exists(select 1 from public.memories m where m.id=mid and m.author_id=me and m.quest_id=task and m.space_completion) then return mid; end if;
  if not q.active then raise exception 'This task already has a memory.'; end if;
  if caption_text is null or trim(caption_text) !~ '[^[:space:]]' or length(trim(caption_text))>220 then raise exception 'Add a caption of up to 220 characters.'; end if;
  if not exists(select 1 from storage.objects where bucket_id='memory-photos' and name=photo) then raise exception 'Upload the photo first.'; end if;
  insert into public.memories(id,group_id,quest_id,author_id,caption,image_path,quest_title,space_completion)
    values(mid,q.group_id,task,me,trim(caption_text),photo,q.title,true);
  insert into public.memory_people select mid,m.user_id from public.group_members m where m.group_id=q.group_id;
  update public.quests set active=false where id=task;
  return mid;
end $$;
revoke all on function public.start_memory_space(uuid,text,text,uuid[],text,text), public.finish_memory_task(uuid,uuid,text) from public,anon;
grant execute on function public.start_memory_space(uuid,text,text,uuid[],text,text), public.finish_memory_task(uuid,uuid,text) to authenticated;
commit;
