begin;

-- Existing Auth users may predate the new-user trigger. Give each one the
-- profile needed by the group's creator foreign key without replacing profiles.
insert into public.profiles (id, display_name, avatar_url)
select id, coalesce(raw_user_meta_data->>'full_name', raw_user_meta_data->>'name', 'Side-quester'),
       raw_user_meta_data->>'avatar_url'
from auth.users
on conflict (id) do nothing;

-- A posted photo must belong to the author. This prevents an unrelated group
-- from granting itself read access by referencing another user's object path.
drop policy if exists "members add memories" on public.memories;
create policy "members add memories" on public.memories for insert to authenticated
with check (
  author_id = auth.uid() and public.is_member(group_id)
  and (storage.foldername(image_path))[1] = auth.uid()::text
);

drop policy if exists "users read group proof" on storage.objects;
create policy "users read group proof" on storage.objects for select to authenticated
using (
  bucket_id = 'memory-photos' and (
    (storage.foldername(name))[1] = auth.uid()::text or exists (
      select 1 from public.memories m
      where m.image_path = storage.objects.name
        and m.author_id::text = (storage.foldername(storage.objects.name))[1]
        and public.is_member(m.group_id)
    )
  )
);

commit;
