-- ============================================================
-- 007_contacts_and_documents.sql
-- Contacts directory + Documents storage
-- Run in: https://supabase.com/dashboard/project/pclawaxmilduvfkwhhge/sql/new
-- ============================================================

-- ============================================================
-- 1. CONTACTS TABLE
-- ============================================================
create table if not exists public.contacts (
  id           uuid primary key default gen_random_uuid(),
  building_id  uuid references public.buildings(id) on delete cascade not null,
  name         text not null,
  phone        text not null,
  description  text,
  created_by   uuid references public.profiles(id) not null,
  created_at   timestamptz default now()
);

alter table public.contacts enable row level security;

-- Building members can read contacts
create policy "building_members_read_contacts"
  on public.contacts for select
  using (building_id = auth_building_id());

-- Managers can insert contacts for their building
create policy "managers_insert_contacts"
  on public.contacts for insert
  with check (
    auth_role() = 'manager'
    and building_id = auth_building_id()
    and created_by = auth.uid()
  );

-- Managers can update contacts in their building
create policy "managers_update_contacts"
  on public.contacts for update
  using (
    auth_role() = 'manager'
    and building_id = auth_building_id()
  );

-- Managers can delete contacts in their building
create policy "managers_delete_contacts"
  on public.contacts for delete
  using (
    auth_role() = 'manager'
    and building_id = auth_building_id()
  );

-- ============================================================
-- 2. DOCUMENTS TABLE
-- ============================================================
create table if not exists public.documents (
  id           uuid primary key default gen_random_uuid(),
  building_id  uuid references public.buildings(id) on delete cascade not null,
  name         text not null,
  file_url     text not null,
  file_size    bigint,
  created_by   uuid references public.profiles(id) not null,
  created_at   timestamptz default now()
);

alter table public.documents enable row level security;

-- Building members can read document metadata
create policy "building_members_read_documents"
  on public.documents for select
  using (building_id = auth_building_id());

-- Managers can upload documents for their building
create policy "managers_insert_documents"
  on public.documents for insert
  with check (
    auth_role() = 'manager'
    and building_id = auth_building_id()
    and created_by = auth.uid()
  );

-- Managers can delete documents in their building
create policy "managers_delete_documents"
  on public.documents for delete
  using (
    auth_role() = 'manager'
    and building_id = auth_building_id()
  );

-- ============================================================
-- 3. DOCUMENTS STORAGE BUCKET
-- ============================================================
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'documents',
  'documents',
  true,
  20971520, -- 20 MB
  array['application/pdf', 'application/msword',
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        'image/jpeg', 'image/png']
)
on conflict (id) do nothing;

do $$
begin
  if not exists (
    select 1 from pg_policies
     where schemaname = 'storage' and tablename = 'objects'
       and policyname = 'authenticated_upload_documents'
  ) then
    execute $p$
      create policy "authenticated_upload_documents"
        on storage.objects for insert
        with check (
          bucket_id = 'documents'
          and auth.role() = 'authenticated'
        )
    $p$;
  end if;

  if not exists (
    select 1 from pg_policies
     where schemaname = 'storage' and tablename = 'objects'
       and policyname = 'public_read_documents'
  ) then
    execute $p$
      create policy "public_read_documents"
        on storage.objects for select
        using (bucket_id = 'documents')
    $p$;
  end if;

  if not exists (
    select 1 from pg_policies
     where schemaname = 'storage' and tablename = 'objects'
       and policyname = 'authenticated_delete_documents'
  ) then
    execute $p$
      create policy "authenticated_delete_documents"
        on storage.objects for delete
        using (
          bucket_id = 'documents'
          and auth.role() = 'authenticated'
        )
    $p$;
  end if;
end
$$;

-- ============================================================
-- 4. REALTIME
-- ============================================================
alter publication supabase_realtime add table public.contacts;
alter publication supabase_realtime add table public.documents;
