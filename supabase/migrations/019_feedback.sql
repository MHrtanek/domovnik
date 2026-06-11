create table if not exists feedback (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references profiles(id) on delete set null,
  building_id uuid references buildings(id) on delete set null,
  full_name text,
  email text,
  type text not null check (type in ('bug', 'napad', 'ine')),
  message text not null,
  created_at timestamptz not null default now()
);

alter table feedback enable row level security;

create policy "feedback_insert" on feedback
  for insert with check (auth.uid() = user_id);

create policy "feedback_service_select" on feedback
  for select using (true);
