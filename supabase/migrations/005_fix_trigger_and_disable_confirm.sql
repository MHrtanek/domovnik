-- ============================================================
-- 005_fix_trigger_and_disable_confirm.sql
--
-- Run this in the Supabase SQL editor. It:
--   1. Disables email confirmation so signUp() returns a session immediately
--   2. Fixes the trigger to NOT swallow errors silently
--   3. Restores handle_user_signup() as a real upsert-based fallback
--      (called from the app after getting a session, as belt-and-suspenders)
-- ============================================================

-- NOTE: Email confirmation is disabled via the Supabase Dashboard UI:
-- Authentication → Providers → Email → turn off "Confirm email"
-- The auth.config table does not exist on Supabase cloud.

-- ============================================================
-- 1. REBUILD TRIGGER — no silent error swallowing
-- ============================================================
create or replace function handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_role             text;
  v_full_name        text;
  v_building_id      uuid;
  v_building_name    text;
  v_building_address text;
  v_input_building   text;
begin
  v_role             := coalesce(NEW.raw_user_meta_data->>'role', 'resident');
  v_full_name        := NEW.raw_user_meta_data->>'full_name';
  v_building_name    := NEW.raw_user_meta_data->>'building_name';
  v_building_address := NEW.raw_user_meta_data->>'building_address';
  v_input_building   := NEW.raw_user_meta_data->>'building_id';

  -- Idempotency: skip if profile already exists
  if exists (select 1 from public.profiles where id = NEW.id) then
    return NEW;
  end if;

  if v_role not in ('manager', 'resident') then
    v_role := 'resident';
  end if;

  if v_role = 'manager' then
    insert into public.buildings (name, address)
    values (
      coalesce(nullif(trim(v_building_name), ''), 'Nová budova'),
      coalesce(nullif(trim(v_building_address), ''), '')
    )
    returning id into v_building_id;

    insert into public.profiles (id, email, full_name, role, building_id)
    values (NEW.id, coalesce(NEW.email, ''), v_full_name, 'manager', v_building_id);

    update public.buildings
       set manager_id = NEW.id
     where id = v_building_id;
  else
    if v_input_building is not null and v_input_building <> '' then
      begin
        v_building_id := v_input_building::uuid;
      exception when invalid_text_representation then
        v_building_id := null;
      end;
    end if;

    insert into public.profiles (id, email, full_name, role, building_id)
    values (NEW.id, coalesce(NEW.email, ''), v_full_name, 'resident', v_building_id);
  end if;

  return NEW;
  -- NOTE: no EXCEPTION block — let errors surface so they are visible
  -- in Supabase logs rather than silently creating broken accounts.
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function handle_new_user();

-- ============================================================
-- 3. RESTORE handle_user_signup() as a real upsert-based fallback
--    Called from the app after getting a session (belt-and-suspenders).
--    Uses ON CONFLICT DO NOTHING so it's safe to call multiple times.
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
  v_user_id     uuid := auth.uid();
  v_building_id uuid;
begin
  if v_user_id is null then
    raise exception 'handle_user_signup: not authenticated (no session)';
  end if;

  -- If profile already exists (trigger ran), do nothing
  if exists (select 1 from public.profiles where id = v_user_id) then
    select building_id into v_building_id
      from public.profiles where id = v_user_id;
    return json_build_object('building_id', v_building_id, 'source', 'existing');
  end if;

  -- Profile missing (trigger didn't run or failed) — create it now
  if p_role = 'manager' then
    insert into public.buildings (name, address)
    values (
      coalesce(nullif(trim(p_building_name), ''), 'Nová budova'),
      coalesce(nullif(trim(p_building_address), ''), '')
    )
    returning id into v_building_id;

    insert into public.profiles (id, email, full_name, role, building_id)
    values (v_user_id, p_email, p_full_name, 'manager', v_building_id);

    update public.buildings
       set manager_id = v_user_id
     where id = v_building_id;
  else
    v_building_id := p_building_id;

    insert into public.profiles (id, email, full_name, role, building_id)
    values (v_user_id, p_email, p_full_name, 'resident', v_building_id);
  end if;

  return json_build_object('building_id', v_building_id, 'source', 'rpc_fallback');
end;
$$;

grant execute on function handle_user_signup(text, text, text, uuid, text, text)
  to authenticated;
