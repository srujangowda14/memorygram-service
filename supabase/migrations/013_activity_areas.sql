-- Preserve existing plans without inventing a neighborhood from coordinates.
-- Only the owner can edit this self-described public discovery label.
alter table public.activity_plans add column area_label text
 check(area_label is null or (length(trim(area_label)) between 1 and 80));

-- Changing the result shape requires recreating the function and its grants.
-- Coordinate access and the existing radius filter remain unchanged.
drop function public.discover_activity(double precision);
-- Search around the caller's saved opt-in location and exclude expired tags.
-- A hard radius and result cap bound each discovery request.
create function public.discover_activity(radius_km double precision)
returns table(user_id uuid, display_name text, category text, expires_at timestamptz, area_label text)
language plpgsql security definer set search_path=public as $$
begin
 if auth.uid() is null or radius_km is null or not radius_km between 1 and 100 then raise exception 'Choose a radius between 1 and 100 km'; end if;
 return query select p.user_id, pr.display_name, p.category, p.expires_at, p.area_label
 from activity_plans p join profiles pr on pr.id=p.user_id
 join activity_plans me on me.user_id=auth.uid()
 where p.user_id<>auth.uid() and p.expires_at>now() and me.expires_at>now() and p.category=me.category
 and 6371*2*asin(sqrt(least(1.0,power(sin(radians(p.latitude-me.latitude)/2),2)+cos(radians(me.latitude))*cos(radians(p.latitude))*power(sin(radians(p.longitude-me.longitude)/2),2))))<=radius_km
 order by p.expires_at limit 100;
end $$;
revoke all on function public.discover_activity(double precision) from public;
grant execute on function public.discover_activity(double precision) to authenticated;
