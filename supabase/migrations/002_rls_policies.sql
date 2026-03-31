-- ============================================================
-- 002_rls_policies.sql
-- Row Level Security policies
-- ============================================================

-- Helper function: get current user's profile building_id
create or replace function auth_building_id()
returns uuid
language sql stable
security definer
as $$
  select building_id from profiles where id = auth.uid();
$$;

-- Helper function: get current user's role
create or replace function auth_role()
returns text
language sql stable
security definer
as $$
  select role from profiles where id = auth.uid();
$$;

-- ============================================================
-- BUILDINGS
-- ============================================================
alter table buildings enable row level security;

-- Residents can read their own building
create policy "residents_read_own_building"
  on buildings for select
  using (id = auth_building_id());

-- Managers can read their own building
create policy "managers_read_own_building"
  on buildings for select
  using (manager_id = auth.uid());

-- Managers can create buildings
create policy "managers_create_buildings"
  on buildings for insert
  with check (auth_role() = 'manager');

-- Managers can update their own building
create policy "managers_update_own_building"
  on buildings for update
  using (manager_id = auth.uid());

-- ============================================================
-- PROFILES
-- ============================================================
alter table profiles enable row level security;

-- Users can read their own profile
create policy "users_read_own_profile"
  on profiles for select
  using (id = auth.uid());

-- Managers can read all profiles in their building
create policy "managers_read_building_profiles"
  on profiles for select
  using (
    building_id = auth_building_id()
    and auth_role() = 'manager'
  );

-- Users can insert their own profile (on signup)
create policy "users_insert_own_profile"
  on profiles for insert
  with check (id = auth.uid());

-- Users can update their own profile
create policy "users_update_own_profile"
  on profiles for update
  using (id = auth.uid());

-- ============================================================
-- TICKETS
-- ============================================================
alter table tickets enable row level security;

-- Residents can insert tickets for their building
create policy "residents_insert_tickets"
  on tickets for insert
  with check (
    auth_role() = 'resident'
    and building_id = auth_building_id()
    and created_by = auth.uid()
  );

-- Residents can read their own tickets
create policy "residents_read_own_tickets"
  on tickets for select
  using (
    auth_role() = 'resident'
    and created_by = auth.uid()
  );

-- Managers can read all tickets in their building
create policy "managers_read_building_tickets"
  on tickets for select
  using (
    auth_role() = 'manager'
    and building_id = auth_building_id()
  );

-- Managers can update tickets in their building
create policy "managers_update_building_tickets"
  on tickets for update
  using (
    auth_role() = 'manager'
    and building_id = auth_building_id()
  );

-- ============================================================
-- ANNOUNCEMENTS
-- ============================================================
alter table announcements enable row level security;

-- All authenticated users in the same building can read announcements
create policy "building_members_read_announcements"
  on announcements for select
  using (building_id = auth_building_id());

-- Managers can insert announcements for their building
create policy "managers_insert_announcements"
  on announcements for insert
  with check (
    auth_role() = 'manager'
    and building_id = auth_building_id()
    and created_by = auth.uid()
  );

-- Managers can delete their own announcements
create policy "managers_delete_own_announcements"
  on announcements for delete
  using (
    auth_role() = 'manager'
    and created_by = auth.uid()
  );

-- ============================================================
-- POLLS
-- ============================================================
alter table polls enable row level security;

-- All building members can read polls
create policy "building_members_read_polls"
  on polls for select
  using (building_id = auth_building_id());

-- Managers can create polls for their building
create policy "managers_insert_polls"
  on polls for insert
  with check (
    auth_role() = 'manager'
    and building_id = auth_building_id()
    and created_by = auth.uid()
  );

-- Managers can delete their own polls
create policy "managers_delete_own_polls"
  on polls for delete
  using (
    auth_role() = 'manager'
    and created_by = auth.uid()
  );

-- ============================================================
-- POLL OPTIONS
-- ============================================================
alter table poll_options enable row level security;

-- All building members can read poll options
create policy "building_members_read_poll_options"
  on poll_options for select
  using (
    exists (
      select 1 from polls
      where polls.id = poll_options.poll_id
        and polls.building_id = auth_building_id()
    )
  );

-- Managers can insert poll options (when creating a poll)
create policy "managers_insert_poll_options"
  on poll_options for insert
  with check (
    auth_role() = 'manager'
    and exists (
      select 1 from polls
      where polls.id = poll_options.poll_id
        and polls.created_by = auth.uid()
    )
  );

-- ============================================================
-- POLL VOTES
-- ============================================================
alter table poll_votes enable row level security;

-- All building members can read votes (for result tallying)
create policy "building_members_read_votes"
  on poll_votes for select
  using (building_id = auth_building_id());

-- Any authenticated building member can vote
create policy "building_members_insert_votes"
  on poll_votes for insert
  with check (
    user_id = auth.uid()
    and building_id = auth_building_id()
  );
