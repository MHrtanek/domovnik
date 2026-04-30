create table if not exists house_rules (
  id uuid primary key default gen_random_uuid(),
  building_id uuid not null references buildings(id) on delete cascade,
  content text not null default '',
  updated_by uuid references profiles(id),
  updated_at timestamptz not null default now(),
  constraint house_rules_building_id_key unique (building_id)
);

alter table house_rules enable row level security;

-- Residents and managers of the building can read
create policy "house_rules_select" on house_rules
  for select using (
    building_id in (
      select building_id from profiles where id = auth.uid()
    )
  );

-- Only managers can insert/update
create policy "house_rules_upsert" on house_rules
  for all using (
    building_id in (
      select building_id from profiles where id = auth.uid() and role = 'manager'
    )
  );
