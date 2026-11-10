-- Birth dates are visible only to the profile owner. Group organizers receive
-- an aggregate band for their selected mutual friends, including themselves.
create table public.profile_birthdays (
  user_id uuid primary key references auth.users(id) on delete cascade,
  birthday date not null check (birthday <= current_date and birthday > (current_date - interval '121 years')::date)
);
alter table public.profile_birthdays enable row level security;
revoke all on public.profile_birthdays from public, anon, authenticated;
grant select, insert, update on public.profile_birthdays to authenticated;
create policy own_birthday on public.profile_birthdays for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- Check friendship before reading private dates. Missing dates, widely mixed
-- ages and middle pairs in different bands keep the group on all-ages quests.
create function public.group_profile_range(companions uuid[]) returns text
language plpgsql stable security definer set search_path = '' as $$
declare me uuid := auth.uid(); bands integer[]; n integer;
begin
  if me is null or companions is null or cardinality(companions) not between 1 and 19
    or cardinality(companions) <> (select count(distinct x) from unnest(companions) x)
    or exists(select 1 from unnest(companions) x where x=me or not exists (
      select 1 from public.follows a join public.follows b on b.target=a.follower and b.follower=a.target
      where a.follower=me and a.target=x and a.status='accepted' and b.status='accepted'))
    then raise exception 'Choose mutual friends.'; end if;
  select array_agg(b order by b) into bands from (
    select case when years<30 then 1 when years<50 then 2 when years<65 then 3 else 4 end b
    from (select extract(year from age(current_date,birthday)) years from public.profile_birthdays
      where user_id=any(array_append(companions,me))) ages) ranked;
  n := cardinality(companions)+1;
  if coalesce(cardinality(bands),0)<>n or bands[n]-bands[1]>=2 or bands[(n+1)/2]<>bands[(n+2)/2]
    then return 'All ages'; end if;
  return (array['Under 30','30–49','50–64','65+'])[bands[(n+1)/2]];
end $$;
revoke all on function public.group_profile_range(uuid[]) from public,anon;
grant execute on function public.group_profile_range(uuid[]) to authenticated;
