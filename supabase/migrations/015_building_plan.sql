create table if not exists building_plan (
  building_id uuid primary key references buildings(id) on delete cascade,
  file_url text not null,
  updated_at timestamptz not null default now()
);

alter table building_plan enable row level security;

create policy "read" on building_plan
  for select using (
    building_id in (select building_id from profiles where id = auth.uid())
  );

create policy "manager write" on building_plan
  for all using (
    building_id in (
      select building_id from profiles where id = auth.uid() and role = 'manager'
    )
  );
