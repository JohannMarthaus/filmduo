-- Filmduo: Datenbank in Supabase einrichten
-- Komplett in Supabase → SQL Editor → New query einfügen und auf „Run“ klicken.
-- Kann gefahrlos mehrmals ausgeführt werden.

-- ---------- Tabellen ----------

-- Ein Duo: 6-stelliger Code, höchstens zwei Mitglieder
create table if not exists public.pairs (
  code       text primary key check (code ~ '^[A-HJ-NP-Z2-9]{6}$'),
  members    uuid[] not null default '{}' check (cardinality(members) <= 2),
  created_at timestamptz not null default now()
);

-- Anzeigename pro Person
create table if not exists public.profiles (
  user_id    uuid primary key default auth.uid() references auth.users on delete cascade,
  name       text not null check (char_length(name) between 1 and 40),
  updated_at timestamptz not null default now()
);

-- Swipes: wer hat was in welchem Duo gemocht
create table if not exists public.swipes (
  pair    text not null references public.pairs on delete cascade,
  user_id uuid not null default auth.uid(),
  item    text not null check (char_length(item) between 1 and 100),
  liked   boolean not null,
  t       timestamptz not null default now(),
  primary key (pair, user_id, item)
);

-- Gemeinsam gesehene Matches
create table if not exists public.watched (
  pair text not null references public.pairs on delete cascade,
  item text not null check (char_length(item) between 1 and 100),
  by   uuid not null default auth.uid(),
  t    timestamptz not null default now(),
  primary key (pair, item)
);

-- Selbst hinzugefügte Titel
create table if not exists public.custom (
  pair   text not null references public.pairs on delete cascade,
  id     text not null check (char_length(id) between 1 and 100),
  title  text not null check (char_length(title) between 1 and 80),
  year   int  not null check (year between 1900 and 2100),
  type   text not null check (type in ('f','s')),
  genres text[] not null default '{}' check (cardinality(genres) <= 3),
  descr  text not null default '' check (char_length(descr) <= 200),
  by     uuid not null default auth.uid(),
  t      timestamptz not null default now(),
  primary key (pair, id)
);

-- ---------- Hilfsfunktion ----------

create or replace function public.is_member(p text) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.pairs where code = p and auth.uid() = any(members));
$$;

-- ---------- Duo erstellen / beitreten / verlassen ----------
-- Laufen mit erhöhten Rechten, damit niemand fremde Duos lesen oder ändern kann.

create or replace function public.create_pair() returns text
language plpgsql security definer set search_path = '' as $$
declare
  chars constant text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  c text;
  i int;
begin
  if auth.uid() is null then raise exception 'not_signed_in'; end if;
  if (select count(*) from public.pairs where auth.uid() = any(members) and created_at > now() - interval '1 hour') >= 5 then
    raise exception 'too_many';
  end if;
  for attempt in 1..10 loop
    c := '';
    for i in 1..6 loop
      c := c || substr(chars, 1 + floor(random() * length(chars))::int, 1);
    end loop;
    begin
      insert into public.pairs (code, members) values (c, array[auth.uid()]);
      return c;
    exception when unique_violation then
      -- Code schon vergeben, neuer Versuch
    end;
  end loop;
  raise exception 'no_code';
end;
$$;

create or replace function public.join_pair(p text) returns text
language plpgsql security definer set search_path = '' as $$
declare m uuid[];
begin
  if auth.uid() is null then raise exception 'not_signed_in'; end if;
  select members into m from public.pairs where code = upper(p) for update;
  if not found then raise exception 'not_found'; end if;
  if auth.uid() = any(m) then return upper(p); end if;
  if cardinality(m) >= 2 then raise exception 'full'; end if;
  update public.pairs set members = array_append(members, auth.uid()) where code = upper(p);
  return upper(p);
end;
$$;

create or replace function public.leave_pair(p text) returns void
language plpgsql security definer set search_path = '' as $$
begin
  update public.pairs set members = array_remove(members, auth.uid()) where code = upper(p);
end;
$$;

-- ---------- Zugriffsregeln (Row Level Security) ----------

alter table public.pairs    enable row level security;
alter table public.profiles enable row level security;
alter table public.swipes   enable row level security;
alter table public.watched  enable row level security;
alter table public.custom   enable row level security;

drop policy if exists "Mitglieder sehen ihr Duo" on public.pairs;
create policy "Mitglieder sehen ihr Duo" on public.pairs
  for select to authenticated using (auth.uid() = any(members));

drop policy if exists "Eigenes Profil und Duo-Partner lesen" on public.profiles;
create policy "Eigenes Profil und Duo-Partner lesen" on public.profiles
  for select to authenticated using (
    user_id = auth.uid()
    or exists (select 1 from public.pairs p where auth.uid() = any(p.members) and profiles.user_id = any(p.members))
  );
drop policy if exists "Eigenes Profil anlegen" on public.profiles;
create policy "Eigenes Profil anlegen" on public.profiles
  for insert to authenticated with check (user_id = auth.uid());
drop policy if exists "Eigenes Profil ändern" on public.profiles;
create policy "Eigenes Profil ändern" on public.profiles
  for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

drop policy if exists "Swipes im Duo lesen" on public.swipes;
create policy "Swipes im Duo lesen" on public.swipes
  for select to authenticated using (public.is_member(pair));
drop policy if exists "Eigene Swipes anlegen" on public.swipes;
create policy "Eigene Swipes anlegen" on public.swipes
  for insert to authenticated with check (user_id = auth.uid() and public.is_member(pair));
drop policy if exists "Eigene Swipes ändern" on public.swipes;
create policy "Eigene Swipes ändern" on public.swipes
  for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid() and public.is_member(pair));
drop policy if exists "Eigene Swipes löschen" on public.swipes;
create policy "Eigene Swipes löschen" on public.swipes
  for delete to authenticated using (user_id = auth.uid());

drop policy if exists "Gesehen im Duo" on public.watched;
create policy "Gesehen im Duo" on public.watched
  for all to authenticated using (public.is_member(pair)) with check (public.is_member(pair));

drop policy if exists "Eigene Titel im Duo lesen" on public.custom;
create policy "Eigene Titel im Duo lesen" on public.custom
  for select to authenticated using (public.is_member(pair));
drop policy if exists "Eigene Titel anlegen" on public.custom;
create policy "Eigene Titel anlegen" on public.custom
  for insert to authenticated with check (by = auth.uid() and public.is_member(pair));

-- ---------- Rechte ----------

revoke all on public.pairs, public.profiles, public.swipes, public.watched, public.custom from anon;
grant select on public.pairs to authenticated;
grant select, insert, update on public.profiles to authenticated;
grant select, insert, update, delete on public.swipes, public.watched to authenticated;
grant select, insert on public.custom to authenticated;

revoke all on function public.is_member(text), public.create_pair(), public.join_pair(text), public.leave_pair(text) from public, anon;
grant execute on function public.is_member(text), public.create_pair(), public.join_pair(text), public.leave_pair(text) to authenticated;

-- ---------- Wachhalten ----------
-- Die nächtliche GitHub Action ruft ping() auf, damit Supabase das kostenlose Projekt nicht pausiert.
create or replace function public.ping() returns text
language sql stable set search_path = '' as $$ select 'ok'::text $$;
revoke all on function public.ping() from public;
grant execute on function public.ping() to anon, authenticated;

-- ---------- Wachhalten ----------
-- Die nächtliche GitHub Action ruft das auf, damit Supabase das kostenlose Projekt nicht pausiert.
create or replace function public.ping() returns text
language sql stable set search_path = '' as $$ select 'ok'::text $$;
revoke all on function public.ping() from public;
grant execute on function public.ping() to anon, authenticated;

-- ---------- Live-Aktualisierung (neue Matches sofort sehen) ----------

do $$
declare t text;
begin
  foreach t in array array['pairs','swipes','watched','custom'] loop
    if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = t) then
      execute format('alter publication supabase_realtime add table public.%I', t);
    end if;
  end loop;
end $$;

-- Fertig. Unten sollte „Success. No rows returned“ stehen.
