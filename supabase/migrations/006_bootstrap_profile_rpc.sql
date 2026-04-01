-- ============================================================
-- 006_bootstrap_profile_rpc.sql
--
-- Run this in Supabase SQL Editor:
-- https://supabase.com/dashboard/project/pclawaxmilduvfkwhhge/sql/new
--
-- This is the SINGLE migration you need to run if you haven't run
-- 003–005, or if those failed. It is fully idempotent.
--
-- What it does:
--   1. Ensures buildings has a public-read policy (for signup dropdown)
--   2. Creates/replaces handle_user_signup() as a robust upsert RPC
--      (SECURITY DEFINER, works with any valid session)
--   3. Creates/replaces the on_auth_user_created trigger (fires on
--      INSERT into auth.users, no session required)
--   4. Creates the ticket-photos storage bucket if it doesn't exist
-- ============================================================

-- ============================================================
-- 1. BUILDINGS: allow any authenticated user to list all buildings
--    (needed on the registration screen before a profile exists)
-- ============================================================
do $$
begin
  if not exists (
    select 1 from pg_policies
     where schemaname = 'public'
       and tablename  = 'buildings'
       and policyname = 'all_can_read_buildings'
  ) then
    execute $policy$
      create policy "all_can_read_buildings"
        on public.buildings for select
        using (true)
    $policy$;
  end if;
end
$$;

-- ============================================================
-- 2. handle_user_signup() — SECURITY DEFINER RPC
--    Called from Flutter after a session exists (belt-and-suspenders).
--    Safe to call multiple times: returns immediately if profile exists.
-- ============================================================
create or replace function public.handle_user_signup(
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
  v_user_id     uuid := auth.uid();
  v_building_id uuid;
begin
  if v_user_id is null then
    raise exception 'handle_user_signup: not authenticated';
  end if;

  -- Idempotency: profile already exists → return its building_id
  if exists (select 1 from public.profiles where id = v_user_id) then
    select building_id into v_building_id
      from public.profiles where id = v_user_id;
    return json_build_object('building_id', v_building_id, 'created', false);
  end if;

  if p_role = 'manager' then
    -- Create building first (no manager_id yet to avoid FK cycle)
    insert into public.buildings (name, address)
    values (
      coalesce(nullif(trim(p_building_name),    ''), 'Nová budova'),
      coalesce(nullif(trim(p_building_address), ''), '')
    )
    returning id into v_building_id;

    -- Create profile
    insert into public.profiles (id, email, full_name, role, building_id)
    values (v_user_id, p_email, p_full_name, 'manager', v_building_id);

    -- Back-link building → manager
    update public.buildings
       set manager_id = v_user_id
     where id = v_building_id;

  else
    v_building_id := p_building_id;

    insert into public.profiles (id, email, full_name, role, building_id)
    values (v_user_id, p_email, p_full_name, 'resident', v_building_id);
  end if;

  return json_build_object('building_id', v_building_id, 'created', true);
end;
$$;

grant execute on function public.handle_user_signup(text, text, text, uuid, text, text)
  to authenticated;

-- ============================================================
-- 3. on_auth_user_created trigger
--    Fires AFTER INSERT ON auth.users — no session needed.
--    Reads metadata stored via signUp(data:{}) in Flutter.
--    This is the primary path; handle_user_signup() is the fallback.
-- ============================================================
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_role         text;
  v_full_name    text;
  v_bld_name     text;
  v_bld_address  text;
  v_bld_id_raw   text;
  v_building_id  uuid;
begin
  v_role        := coalesce(NEW.raw_user_meta_data->>'role', 'resident');
  v_full_name   := NEW.raw_user_meta_data->>'full_name';
  v_bld_name    := NEW.raw_user_meta_data->>'building_name';
  v_bld_address := NEW.raw_user_meta_data->>'building_address';
  v_bld_id_raw  := NEW.raw_user_meta_data->>'building_id';

  -- Skip if profile already exists (idempotency)
  if exists (select 1 from public.profiles where id = NEW.id) then
    return NEW;
  end if;

  if v_role not in ('manager', 'resident') then
    v_role := 'resident';
  end if;

  if v_role = 'manager' then
    insert into public.buildings (name, address)
    values (
      coalesce(nullif(trim(v_bld_name),    ''), 'Nová budova'),
      coalesce(nullif(trim(v_bld_address), ''), '')
    )
    returning id into v_building_id;

    insert into public.profiles (id, email, full_name, role, building_id)
    values (NEW.id, coalesce(NEW.email, ''), v_full_name, 'manager', v_building_id);

    update public.buildings
       set manager_id = NEW.id
     where id = v_building_id;

  else
    if v_bld_id_raw is not null and v_bld_id_raw <> '' then
      begin
        v_building_id := v_bld_id_raw::uuid;
      exception when invalid_text_representation then
        v_building_id := null;
      end;
    end if;

    insert into public.profiles (id, email, full_name, role, building_id)
    values (NEW.id, coalesce(NEW.email, ''), v_full_name, 'resident', v_building_id);
  end if;

  return NEW;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row
  execute function public.handle_new_user();

-- ============================================================
-- 4. ticket-photos storage bucket
-- ============================================================
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'ticket-photos',
  'ticket-photos',
  true,
  5242880,
  array['image/jpeg', 'image/jpg', 'image/png', 'image/webp', 'image/gif']
)
on conflict (id) do nothing;

do $$
begin
  if not exists (
    select 1 from pg_policies
     where schemaname = 'storage'
       and tablename  = 'objects'
       and policyname = 'authenticated_upload_ticket_photos'
  ) then
    execute $policy$
      create policy "authenticated_upload_ticket_photos"
        on storage.objects for insert
        with check (
          bucket_id = 'ticket-photos'
          and auth.role() = 'authenticated'
        )
    $policy$;
  end if;

  if not exists (
    select 1 from pg_policies
     where schemaname = 'storage'
       and tablename  = 'objects'
       and policyname = 'public_read_ticket_photos'
  ) then
    execute $policy$
      create policy "public_read_ticket_photos"
        on storage.objects for select
        using (bucket_id = 'ticket-photos')
    $policy$;
  end if;
end
$$;

-- ============================================================
-- 5. VERIFY — run these selects to confirm everything worked
-- ============================================================
-- select trigger_name, event_object_table from information_schema.triggers
--  where trigger_name = 'on_auth_user_created';
--
-- select routine_name from information_schema.routines
--  where routine_name in ('handle_new_user','handle_user_signup');
--
-- select id, name from storage.buckets where id = 'ticket-photos';
