-- 016_supplier_access.sql
-- Add 'dodavatel' (supplier/contractor) role with scoped ticket access

-- ─── 1. Profiles: extend role constraint to allow 'dodavatel' ────────────────
DO $$
DECLARE v_name text;
BEGIN
  SELECT conname INTO v_name
  FROM pg_constraint
  WHERE conrelid = 'profiles'::regclass
    AND contype = 'c'
    AND pg_get_constraintdef(oid) LIKE '%role%';
  IF v_name IS NOT NULL THEN
    EXECUTE format('ALTER TABLE profiles DROP CONSTRAINT %I', v_name);
  END IF;
END $$;

ALTER TABLE profiles
  ADD CONSTRAINT profiles_role_check
  CHECK (role IN ('manager', 'resident', 'dodavatel'));

-- ─── 2. Tickets: add supplier_id column ──────────────────────────────────────
ALTER TABLE tickets
  ADD COLUMN IF NOT EXISTS supplier_id uuid
  REFERENCES profiles(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS tickets_supplier_id_idx ON tickets (supplier_id);

-- ─── 3. RLS: dodavatel can read and update only their assigned tickets ────────
CREATE POLICY "dodavatel_select_assigned_tickets"
  ON tickets FOR SELECT
  TO authenticated
  USING (supplier_id = auth.uid());

CREATE POLICY "dodavatel_update_assigned_tickets"
  ON tickets FOR UPDATE
  TO authenticated
  USING (supplier_id = auth.uid())
  WITH CHECK (supplier_id = auth.uid());

-- ─── 4. invite_codes: add role column (supports dodavatel invites) ────────────
ALTER TABLE invite_codes
  ADD COLUMN IF NOT EXISTS role text NOT NULL DEFAULT 'resident';

DO $$
BEGIN
  ALTER TABLE invite_codes
    ADD CONSTRAINT invite_codes_role_check
    CHECK (role IN ('resident', 'dodavatel'));
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- ─── 5. RPC: manager generates a single-use dodavatel invite code ─────────────
CREATE OR REPLACE FUNCTION generate_supplier_invite(p_building_id uuid)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_code text;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM profiles
    WHERE id = auth.uid()
      AND role = 'manager'
      AND building_id = p_building_id
  ) THEN
    RAISE EXCEPTION 'Len správca budovy môže generovať pozvánky pre dodávateľov';
  END IF;

  v_code := upper(substring(md5(random()::text || clock_timestamp()::text), 1, 8));

  INSERT INTO invite_codes (code, building_id, role, created_by, expires_at)
  VALUES (v_code, p_building_id, 'dodavatel', auth.uid(), now() + interval '30 days');

  RETURN v_code;
END;
$$;

GRANT EXECUTE ON FUNCTION generate_supplier_invite(uuid) TO authenticated;
