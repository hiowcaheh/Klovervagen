-- ============================================================
--  DZIENNIK REMONTU — konfiguracja bazy danych Supabase
--  Wklej całość do: Supabase → SQL Editor → New query → Run
--  Wykonujesz to TYLKO RAZ.
-- ============================================================

-- 1) Tabela ETAPÓW
create table if not exists stages (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  priority text not null default 'mid',
  budget numeric not null default 0,
  color text not null default '#d4742a',
  note text default '',
  created_at timestamptz default now()
);

-- 2) Tabela ZADAŃ
create table if not exists todos (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  text text not null,
  stage_id uuid references stages(id) on delete set null,
  priority text not null default 'mid',
  done boolean not null default false,
  created_at timestamptz default now()
);

-- 3) Tabela WYDATKÓW
create table if not exists costs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null,
  amount numeric not null default 0,
  stage_id uuid references stages(id) on delete set null,
  date date not null default current_date,
  note text default '',
  file_path text,
  file_type text,
  file_name text,
  created_at timestamptz default now()
);

-- 4) Ustawienia użytkownika (nazwa domu)
create table if not exists settings (
  user_id uuid primary key references auth.users(id) on delete cascade,
  house_name text default 'Mój Dom'
);

-- ============================================================
--  BEZPIECZEŃSTWO: każdy widzi TYLKO swoje dane (RLS)
-- ============================================================
alter table stages   enable row level security;
alter table todos    enable row level security;
alter table costs    enable row level security;
alter table settings enable row level security;

create policy "own_stages"   on stages   for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "own_todos"    on todos    for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "own_costs"    on costs    for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "own_settings" on settings for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- ============================================================
--  STORAGE: kubełek na zdjęcia paragonów i pliki PDF
-- ============================================================
insert into storage.buckets (id, name, public)
values ('paragony', 'paragony', false)
on conflict (id) do nothing;

create policy "own_files_read"   on storage.objects for select
  using (bucket_id = 'paragony' and auth.uid()::text = (storage.foldername(name))[1]);
create policy "own_files_insert" on storage.objects for insert
  with check (bucket_id = 'paragony' and auth.uid()::text = (storage.foldername(name))[1]);
create policy "own_files_delete" on storage.objects for delete
  using (bucket_id = 'paragony' and auth.uid()::text = (storage.foldername(name))[1]);
-- ============================================================
--  POMYSŁY: rozmowy z AI i ustalenia
-- ============================================================
create table if not exists ideas (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  title text not null,
  icon text not null default '💡',
  stage_id uuid references stages(id) on delete set null,
  status text not null default 'active' check (status in ('active','done')),
  last_snippet text not null default '',
  tasks_added integer not null default 0,
  shop_added integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table if not exists idea_messages (
  id uuid primary key default gen_random_uuid(),
  idea_id uuid not null references ideas(id) on delete cascade,
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  role text not null check (role in ('user','assistant')),
  content text not null default '',
  raw text,
  image_path text,
  meta jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create table if not exists idea_facts (
  id uuid primary key default gen_random_uuid(),
  idea_id uuid not null references ideas(id) on delete cascade,
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  category text not null default 'Inne',
  label text not null,
  value text not null,
  source text not null default 'ai',
  history jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table ideas         enable row level security;
alter table idea_messages enable row level security;
alter table idea_facts    enable row level security;
create policy "own_ideas"         on ideas         for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "own_idea_messages" on idea_messages for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "own_idea_facts"    on idea_facts    for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
