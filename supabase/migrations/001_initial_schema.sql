-- ============================================================
-- 001_initial_schema.sql
-- Slovenský Digitálny Domovník – initial database schema
-- ============================================================

-- Enable UUID extension
create extension if not exists "pgcrypto";

-- ============================================================
-- ENUMS
-- ============================================================
create type ticket_category as enum (
  'Vodoinštalácia',
  'Elektrina',
  'Výťah',
  'Spoločné priestory',
  'Iné'
);

create type ticket_status as enum (
  'Prijaté',
  'V riešení',
  'Ukončené'
);

-- ============================================================
-- BUILDINGS
-- (created before profiles because profiles references it,
--  but manager_id is added after profiles via alter table)
-- ============================================================
create table buildings (
  id          uuid primary key default gen_random_uuid(),
  name        text not null,
  address     text not null,
  manager_id  uuid,  -- FK added after profiles table created
  created_at  timestamptz default now()
);

-- ============================================================
-- PROFILES
-- ============================================================
create table profiles (
  id           uuid primary key references auth.users(id) on delete cascade,
  email        text not null,
  full_name    text,
  flat_number  text,
  role         text check (role in ('resident', 'manager')) not null default 'resident',
  building_id  uuid references buildings(id),
  fcm_token    text,
  created_at   timestamptz default now()
);

-- Add manager_id FK now that profiles exists
alter table buildings
  add constraint buildings_manager_id_fkey
  foreign key (manager_id) references profiles(id);

-- ============================================================
-- TICKETS
-- ============================================================
create table tickets (
  id           uuid primary key default gen_random_uuid(),
  title        text not null,
  description  text,
  category     ticket_category not null,
  status       ticket_status not null default 'Prijaté',
  photo_url    text,
  created_by   uuid references profiles(id) not null,
  building_id  uuid references buildings(id) not null,
  created_at   timestamptz default now(),
  updated_at   timestamptz default now()
);

-- Auto-update updated_at
create or replace function update_updated_at_column()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

create trigger tickets_updated_at
  before update on tickets
  for each row execute function update_updated_at_column();

-- ============================================================
-- ANNOUNCEMENTS
-- ============================================================
create table announcements (
  id           uuid primary key default gen_random_uuid(),
  title        text not null,
  content      text not null,
  is_urgent    boolean default false,
  created_by   uuid references profiles(id) not null,
  building_id  uuid references buildings(id) not null,
  created_at   timestamptz default now()
);

-- ============================================================
-- POLLS
-- ============================================================
create table polls (
  id           uuid primary key default gen_random_uuid(),
  question     text not null,
  building_id  uuid references buildings(id) not null,
  created_by   uuid references profiles(id) not null,
  expires_at   timestamptz,
  created_at   timestamptz default now()
);

create table poll_options (
  id           uuid primary key default gen_random_uuid(),
  poll_id      uuid references polls(id) on delete cascade not null,
  option_text  text not null
);

create table poll_votes (
  id           uuid primary key default gen_random_uuid(),
  poll_id      uuid references polls(id) on delete cascade not null,
  option_id    uuid references poll_options(id) not null,
  user_id      uuid references profiles(id) not null,
  building_id  uuid references buildings(id) not null,
  created_at   timestamptz default now(),
  unique(poll_id, user_id)
);

-- ============================================================
-- Enable Realtime on key tables
-- ============================================================
alter publication supabase_realtime add table tickets;
alter publication supabase_realtime add table announcements;
alter publication supabase_realtime add table polls;
alter publication supabase_realtime add table poll_votes;
