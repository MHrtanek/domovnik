-- ============================================================
-- 004_auth_trigger.sql
-- Replace the RPC-based signup flow with a trigger on auth.users.
--
-- WHY: When Supabase email confirmation is enabled, auth.signUp()
-- returns a user but no session. Calling an RPC immediately after
-- fails because auth.uid() is NULL inside the function (no session
-- yet). The trigger fires on INSERT into auth.users — before email
-- confirmation — so the profile/building are always created.
-- ============================================================

-- ============================================================
-- 1. Trigger function: reads metadata injected via signUp(data:{})
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
  v_input_building_id text;
begin
  -- Pull the values that the Flutter app embeds in signUp(data:{})
  v_role             := NEW.raw_user_meta_data->>'role';
  v_full_name        := NEW.raw_user_meta_data->>'full_name';
  v_building_name    := NEW.raw_user_meta_data->>'building_name';
  v_building_address := NEW.raw_user_meta_data->>'building_address';
  v_input_building_id := NEW.raw_user_meta_data->>'building_id';

  -- Idempotency guard: skip if profile already exists
  if exists (select 1 from public.profiles where id = NEW.id) then
    return NEW;
  end if;

  -- Default role to 'resident' if somehow missing
  if v_role is null or v_role not in ('manager', 'resident') then
    v_role := 'resident';
  end if;

  if v_role = 'manager' then
    -- 1. Create the building (no manager_id yet, avoids FK cycle)
    insert into public.buildings (name, address)
    values (
      coalesce(v_building_name, 'Nová budova'),
      coalesce(v_building_address, '')
    )
    returning id into v_building_id;

    -- 2. Create manager profile linked to building
    insert into public.profiles (id, email, full_name, role, building_id)
    values (NEW.id, NEW.email, v_full_name, 'manager', v_building_id);

    -- 3. Back-link building → manager
    update public.buildings
       set manager_id = NEW.id
     where id = v_building_id;

  else
    -- Resident: link to existing building
    if v_input_building_id is not null and v_input_building_id <> '' then
      v_building_id := v_input_building_id::uuid;
    end if;

    insert into public.profiles (id, email, full_name, role, building_id)
    values (NEW.id, NEW.email, v_full_name, 'resident', v_building_id);
  end if;

  return NEW;
exception
  when others then
    -- Log but don't crash the auth flow
    raise warning 'handle_new_user() failed for user %: %', NEW.id, sqlerrm;
    return NEW;
end;
$$;

-- ============================================================
-- 2. Attach trigger to auth.users
-- ============================================================
drop trigger if exists on_auth_user_created on auth.users;

create trigger on_auth_user_created
  after insert on auth.users
  for each row
  execute function handle_new_user();

-- ============================================================
-- 3. Keep handle_user_signup() but make it a no-op wrapper
--    (safe to call even though the trigger already ran)
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
begin
  -- Profile was already created by the trigger on auth.users insert.
  -- This function is kept for backward compatibility only.
  return json_build_object('status', 'already_handled_by_trigger');
end;
$$;
