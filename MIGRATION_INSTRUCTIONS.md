# Migration & Setup Instructions

## ⚠️ Do these in order — all are required

---

## Step 1 — Disable Email Confirmation in Supabase Dashboard (UI)

1. Go to: https://supabase.com/dashboard/project/pclawaxmilduvfkwhhge/auth/providers
2. Click **Email** provider
3. **Turn OFF** "Confirm email"
4. Save

This makes signUp() return a session immediately.

---

## Step 2 — Run all pending migrations in the SQL editor

Go to: https://supabase.com/dashboard/project/pclawaxmilduvfkwhhge/sql/new

Run each of these files **in order** (skip any you already ran):

### 003_rpc_and_storage.sql
Path: `supabase/migrations/003_rpc_and_storage.sql`
- Adds public read policy on buildings (registration dropdown)
- Creates initial handle_user_signup() RPC
- Creates ticket-photos storage bucket

### 004_auth_trigger.sql
Path: `supabase/migrations/004_auth_trigger.sql`
- Creates on_auth_user_created trigger on auth.users

### 005_fix_trigger_and_disable_confirm.sql
Path: `supabase/migrations/005_fix_trigger_and_disable_confirm.sql`
- Rebuilds trigger without silent error swallowing
- Restores handle_user_signup() as a real upsert-based fallback
- Also attempts to set mailer_autoconfirm = true via SQL (same as Step 1)

### 008_profiles_resident_read.sql
Path: `supabase/migrations/008_profiles_resident_read.sql`
- Adds RLS SELECT policy so residents can read profiles of other users in the same building
- Fixes forum post authors showing as 'Neznámy' for residents

---

## Step 3 — Verify the trigger exists

Run this in the SQL editor:

```sql
select trigger_name, event_object_schema, event_object_table, action_timing
from information_schema.triggers
where trigger_name = 'on_auth_user_created';
```

Expected result: 1 row with `auth` / `users` / `AFTER`.

---

## Step 4 — Test registration

1. Open the app
2. Register as a manager with a new email
3. Should go directly to /dashboard (no email confirmation)
4. Verify profile was created:

```sql
select id, email, full_name, role, building_id from public.profiles order by created_at desc limit 5;
```

---

## How the signup flow works now

```
Flutter signUp(email, password, data: { role, full_name, building_name, ... })
  │
  ├─→ Supabase creates row in auth.users
  │       │
  │       └─→ TRIGGER on_auth_user_created fires SYNCHRONOUSLY
  │               reads raw_user_meta_data
  │               creates buildings row (manager) or links existing
  │               creates profiles row
  │
  ├─→ signUp() returns AuthResponse with session (confirmation disabled)
  │
  └─→ App calls handle_user_signup() RPC as belt-and-suspenders
          if profile already exists → no-op (returns 'existing')
          if trigger failed → creates profile now ('rpc_fallback')
```
