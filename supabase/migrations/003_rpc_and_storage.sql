-- ============================================================
-- 003_rpc_and_storage.sql
-- Fixes:
--   1. Allow anyone to read buildings (needed for registration dropdown)
--   2. Atomic signup RPC (security definer – bypasses RLS)
--   3. Storage bucket + policies for ticket-photos
-- ============================================================

-- ============================================================
-- 1. BUILDINGS – allow any user (including anonymous) to read
--    so the registration screen can list available buildings.
--    Multiple SELECT policies are OR'd by Postgres, so existing
--    per-user policies still work; this just widens read access.
-- ============================================================
create policy "all_can_read_buildings"
  on buildings for select
  using (true);

-- ============================================================
-- 2. ATOMIC SIGNUP FUNCTION
--    Runs as SECURITY DEFINER so it bypasses RLS.
--    Called right after auth.signUp() succeeds.
-- ============================================================
create or replace function handle_user_signup(
  p_email             text,
  p_full_name         text,
  p_role              text,
  p_building_id       uuid    default null,
  p_building_name     text    default null,
  p_building_address  text    default null
)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id     uuid;
  v_building_id uuid;
begin
  v_user_id := auth.uid();

  if v_user_id is null then
    raise exception 'Not authenticated – call this after signUp()';
  end if;

  if p_role = 'manager' then
    -- 1. Create the building (no manager_id yet)
    insert into buildings (name, address)
    values (p_building_name, p_building_address)
    returning id into v_building_id;

    -- 2. Create the manager profile linked to the building
    insert into profiles (id, email, full_name, role, building_id)
    values (v_user_id, p_email, p_full_name, 'manager', v_building_id);

    -- 3. Back-link the building to the manager
    update buildings
       set manager_id = v_user_id
     where id = v_building_id;

  else
    -- Resident: just create a profile pointing at an existing building
    v_building_id := p_building_id;

    insert into profiles (id, email, full_name, role, building_id)
    values (v_user_id, p_email, p_full_name, 'resident', v_building_id);
  end if;

  return json_build_object('building_id', v_building_id);
end;
$$;

-- Grant execute to all authenticated users
grant execute on function handle_user_signup(text, text, text, uuid, text, text)
  to authenticated;

-- ============================================================
-- 3. STORAGE – ticket-photos bucket
-- ============================================================
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'ticket-photos',
  'ticket-photos',
  true,
  5242880,   -- 5 MB
  array['image/jpeg', 'image/jpg', 'image/png', 'image/webp', 'image/gif']
)
on conflict (id) do nothing;

-- Authenticated users may upload photos
create policy "authenticated_upload_ticket_photos"
  on storage.objects for insert
  with check (
    bucket_id = 'ticket-photos'
    and auth.role() = 'authenticated'
  );

-- Anyone may read photos (bucket is public)
create policy "public_read_ticket_photos"
  on storage.objects for select
  using (bucket_id = 'ticket-photos');

-- Uploader may delete their own photos
create policy "authenticated_delete_own_ticket_photos"
  on storage.objects for delete
  using (
    bucket_id = 'ticket-photos'
    and owner = auth.uid()
  );
