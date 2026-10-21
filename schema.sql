-- Count Me In: database setup for Supabase.
-- Paste this whole file into Supabase > SQL Editor > New query, then press Run.

-- 1. Admins (people who can verify venues and remove any event) ---------------
create table if not exists public.admins (
  user_id uuid primary key references auth.users(id) on delete cascade
);
alter table public.admins enable row level security;
-- No policies on purpose: nobody can read or edit this table from the website.

create or replace function public.is_admin()
returns boolean
language sql stable security definer set search_path = public
as $$ select exists (select 1 from public.admins where user_id = auth.uid()) $$;

-- 2. Events -------------------------------------------------------------------
create table if not exists public.events (
  id          uuid primary key default gen_random_uuid(),
  created_by  uuid not null default auth.uid() references auth.users(id) on delete cascade,
  title       text not null check (char_length(title) between 1 and 80),
  type        text not null check (type in ('quiz','music','games','sport','meetup','arts','food','market','other')),
  area        text not null check (char_length(area) between 1 and 40),
  venue       text not null check (char_length(venue) between 1 and 80),
  event_date  date not null,
  event_time  time not null,
  description text not null default '' check (char_length(description) <= 400),
  host_name   text not null check (char_length(host_name) between 1 and 60),
  host_kind   text not null check (host_kind in ('venue','community','person')),
  is_free     boolean not null default true check (is_free),
  verified    boolean not null default false,
  created_at  timestamptz not null default now()
);
create index if not exists events_date_idx on public.events (event_date);
alter table public.events enable row level security;

-- Visitors never read this table directly; they use the feed() function below.
-- Owners and admins can read their own rows (needed for edits and deletes).
drop policy if exists "owner or admin reads" on public.events;
create policy "owner or admin reads" on public.events for select to authenticated
  using (created_by = auth.uid() or public.is_admin());

drop policy if exists "signed-in users post" on public.events;
create policy "signed-in users post" on public.events for insert to authenticated
  with check (created_by = auth.uid() and verified = false and is_free);

drop policy if exists "admins update" on public.events;
create policy "admins update" on public.events for update to authenticated
  using (public.is_admin()) with check (public.is_admin());

drop policy if exists "owner or admin deletes" on public.events;
create policy "owner or admin deletes" on public.events for delete to authenticated
  using (created_by = auth.uid() or public.is_admin());

-- 3. RSVPs (interested / going), one row per person per event -------------------
create table if not exists public.rsvps (
  event_id   uuid not null references public.events(id) on delete cascade,
  user_id    uuid not null default auth.uid() references auth.users(id) on delete cascade,
  status     text not null check (status in ('interested','going')),
  updated_at timestamptz not null default now(),
  primary key (event_id, user_id)
);
alter table public.rsvps enable row level security;

drop policy if exists "read own rsvps" on public.rsvps;
create policy "read own rsvps" on public.rsvps for select to authenticated using (user_id = auth.uid());
drop policy if exists "add own rsvp" on public.rsvps;
create policy "add own rsvp" on public.rsvps for insert to authenticated with check (user_id = auth.uid());
drop policy if exists "change own rsvp" on public.rsvps;
create policy "change own rsvp" on public.rsvps for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
drop policy if exists "remove own rsvp" on public.rsvps;
create policy "remove own rsvp" on public.rsvps for delete to authenticated using (user_id = auth.uid());

-- 4. Reports (3 reports hide an event from everyone except its owner and admins) -
create table if not exists public.reports (
  event_id   uuid not null references public.events(id) on delete cascade,
  user_id    uuid not null default auth.uid() references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (event_id, user_id)
);
alter table public.reports enable row level security;

drop policy if exists "read own reports" on public.reports;
create policy "read own reports" on public.reports for select to authenticated using (user_id = auth.uid());
drop policy if exists "add own report" on public.reports;
create policy "add own report" on public.reports for insert to authenticated with check (user_id = auth.uid());

-- 5. The public feed: upcoming events with counts, minus heavily reported ones --
create or replace function public.feed()
returns table (
  id uuid, created_by uuid, title text, type text, area text, venue text,
  event_date date, event_time time, description text, host_name text, host_kind text,
  verified boolean, created_at timestamptz,
  going_count bigint, interested_count bigint, report_count bigint
)
language sql stable security definer set search_path = public
as $$
  select e.id, e.created_by, e.title, e.type, e.area, e.venue,
         e.event_date, e.event_time, e.description, e.host_name, e.host_kind,
         e.verified, e.created_at,
         (select count(*) from public.rsvps r where r.event_id = e.id and r.status = 'going'),
         (select count(*) from public.rsvps r where r.event_id = e.id and r.status = 'interested'),
         (select count(*) from public.reports x where x.event_id = e.id)
  from public.events e
  where e.event_date >= (now() at time zone 'Europe/London')::date
    and ( (select count(*) from public.reports x where x.event_id = e.id) < 3
          or e.created_by = auth.uid()
          or public.is_admin() )
  order by e.event_date, e.event_time;
$$;

grant execute on function public.feed() to anon, authenticated;
grant execute on function public.is_admin() to anon, authenticated;
