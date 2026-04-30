create table if not exists building_units (
  id uuid primary key default gen_random_uuid(),
  building_id uuid not null references buildings(id) on delete cascade,
  unit_type text not null check (unit_type in ('byt', 'pivnica', 'parkovisko')),
  unit_number text not null,
  floor integer not null default 0,
  resident_id uuid references profiles(id) on delete set null,
  resident_name text,
  note text,
  created_at timestamptz not null default now()
);

alter table building_units enable row level security;

-- All building members can read
create policy "building_units_select" on building_units
  for select using (
    building_id in (
      select building_id from profiles where id = auth.uid()
    )
  );

-- Only managers can insert/update/delete
create policy "building_units_manager_write" on building_units
  for all using (
    building_id in (
      select building_id from profiles where id = auth.uid() and role = 'manager'
    )
  );
