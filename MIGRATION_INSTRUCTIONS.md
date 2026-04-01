# Migration Instructions

## Run migration 003 in Supabase Dashboard

Go to: https://supabase.com/dashboard/project/pclawaxmilduvfkwhhge/sql/new

Paste and run the entire contents of:
`supabase/migrations/003_rpc_and_storage.sql`

This migration:
1. Adds a public read policy on `buildings` (so registration screen can list buildings)
2. Creates the `handle_user_signup` RPC (security definer) that atomically creates building + profile
3. Creates the `ticket-photos` storage bucket with correct policies

After running the migration, registration will work without any manual SQL.
