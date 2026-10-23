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

-- ============================================================
--  PLAN DOMU: punkty instalacji i prywatna konfiguracja
--  (rzut domu i podpowiedzi wgrywa się osobno, nigdy nie do repo)
-- ============================================================
create table if not exists house_plan_points (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  type text not null check (type ~ '^[a-z]{1,20}$'),
  floor text not null check (floor ~ '^[a-z0-9_-]{1,20}$'),
  x double precision not null check (x between -50 and 50),
  y double precision not null check (y between -50 and 50),
  code text not null check (code ~ '^[A-Z]{1,3}[0-9]{1,3}$'),
  note text not null default '' check (char_length(note) <= 300),
  qty integer not null default 1 check (qty between 1 and 999),
  len numeric(6, 2) not null default 0 check (len between 0 and 200),
  grp text not null default '' check (char_length(grp) <= 40),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists house_plan_points_user_idx on house_plan_points (user_id);
create or replace function house_plan_touch_updated_at()
returns trigger language plpgsql security invoker set search_path = '' as $$
begin
  new.updated_at := now();
  return new;
end;
$$;
create trigger house_plan_points_touch_updated_at
  before update on house_plan_points for each row execute function house_plan_touch_updated_at();
alter table house_plan_points enable row level security;
revoke all on table house_plan_points from anon;
create policy "Owner reads plan points"   on house_plan_points for select to authenticated using ((select auth.uid()) = user_id);
create policy "Owner adds plan points"    on house_plan_points for insert to authenticated with check ((select auth.uid()) = user_id);
create policy "Owner changes plan points" on house_plan_points for update to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy "Owner removes plan points" on house_plan_points for delete to authenticated using ((select auth.uid()) = user_id);

create table if not exists house_plan_config (
  user_id uuid not null references auth.users(id) on delete cascade,
  key text not null check (key ~ '^[a-z_]{1,40}$'),
  data jsonb not null,
  updated_at timestamptz not null default now(),
  primary key (user_id, key)
);
alter table house_plan_config enable row level security;
revoke all on table house_plan_config from anon;
revoke insert, update, delete, truncate on table house_plan_config from authenticated;
create policy "Owner reads plan config" on house_plan_config for select to authenticated using ((select auth.uid()) = user_id);
