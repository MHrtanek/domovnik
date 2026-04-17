-- Migration 008: Allow residents to read profiles of other users in the same building
--
-- Problem: residents can only read their own profile (users_read_own_profile policy).
-- This causes forum post authors, reservation owners, etc. to appear as 'Neznámy'
-- because the Flutter app cannot fetch the full_name of other users.
--
-- Fix: add a SELECT policy for residents mirroring the existing manager policy,
-- restricted to the same building_id.

create policy "residents_read_building_profiles"
  on profiles for select
  using (
    building_id = (select building_id from profiles where id = auth.uid())
  );
