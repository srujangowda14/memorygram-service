-- Opt-in activity locations are readable only by their owner. Discovery returns
-- names and tags through a bounded distance query, never coordinates.
create table public.activity_plans (
 user_id uuid primary key references auth.users on delete cascade,
 category text not null check(length(category) between 1 and 40),
 latitude double precision not null check(latitude between -90 and 90),
 longitude double precision not null check(longitude between -180 and 180),
 expires_at timestamptz not null check(expires_at <= now()+interval '7 days')
);
alter table public.activity_plans enable row level security;
create policy activity_owner on public.activity_plans for all to authenticated using(user_id=auth.uid()) with check(user_id=auth.uid());
grant select,insert,update,delete on public.activity_plans to authenticated;

-- Search around the caller's saved opt-in location and exclude expired tags.
-- A hard radius and result cap bound each discovery request.
create function public.discover_activity(radius_km double precision)
returns table(user_id uuid, display_name text, category text, expires_at timestamptz)
language plpgsql security definer set search_path=public as $$
begin
 if auth.uid() is null or radius_km is null or not radius_km between 1 and 100 then raise exception 'Choose a radius between 1 and 100 km'; end if;
 return query select p.user_id, pr.display_name, p.category, p.expires_at
 from activity_plans p join profiles pr on pr.id=p.user_id
 join activity_plans me on me.user_id=auth.uid()
 where p.user_id<>auth.uid() and p.expires_at>now() and me.expires_at>now() and p.category=me.category
 and 6371*2*asin(sqrt(least(1.0,power(sin(radians(p.latitude-me.latitude)/2),2)+cos(radians(me.latitude))*cos(radians(p.latitude))*power(sin(radians(p.longitude-me.longitude)/2),2))))<=radius_km
 order by p.expires_at limit 100;
end $$;
revoke all on function public.discover_activity(double precision) from public;
grant execute on function public.discover_activity(double precision) to authenticated;

create table public.activity_chats (
 id uuid primary key default gen_random_uuid(),
 person_a uuid not null references auth.users on delete cascade,
 person_b uuid not null references auth.users on delete cascade,
 category text not null,
 unique(person_a,person_b), check(person_a<person_b)
);
alter table public.activity_chats enable row level security;
create policy activity_chat_member on public.activity_chats for select to authenticated using(auth.uid() in (person_a,person_b));
grant select on public.activity_chats to authenticated;
create table public.activity_messages (
 id uuid primary key default gen_random_uuid(),
 chat_id uuid not null references activity_chats on delete cascade,
 author_id uuid not null references auth.users on delete cascade,
 body text not null check(length(trim(body)) between 1 and 2000),
 created_at timestamptz not null default now()
);
alter table public.activity_messages enable row level security;
create policy activity_message_read on public.activity_messages for select to authenticated using(exists(select 1 from activity_chats c where c.id=chat_id));
create policy activity_message_send on public.activity_messages for insert to authenticated with check(author_id=auth.uid() and exists(select 1 from activity_chats c where c.id=chat_id));
grant select,insert on public.activity_messages to authenticated;
create index on public.activity_messages(chat_id,created_at);

-- Create or reuse a private pair conversation only for an active nearby match.
-- Existing conversations remain available after the original tags expire.
create function public.start_activity_chat(target uuid, radius_km double precision) returns uuid
language plpgsql security definer set search_path=public as $$
declare result uuid;
begin
 if not exists(select 1 from discover_activity(radius_km) d where d.user_id=target) then raise exception 'This activity is no longer available nearby'; end if;
 insert into activity_chats(person_a,person_b,category)
 select least(auth.uid(),target),greatest(auth.uid(),target),category from activity_plans where user_id=auth.uid()
 on conflict(person_a,person_b) do update set person_a=excluded.person_a returning id into result;
 return result;
end $$;
revoke all on function public.start_activity_chat(uuid,double precision) from public;
grant execute on function public.start_activity_chat(uuid,double precision) to authenticated;
