-- CapacityHub · Squad Map Oven AI
-- Execute este arquivo inteiro no Supabase: SQL Editor → New query → colar → Run.
-- Pode ser executado mais de uma vez (idempotente).

-- ============================================================
-- 1. Perfis e níveis de acesso
-- ============================================================
create table if not exists public.profiles (
  id          uuid primary key references auth.users(id) on delete cascade,
  email       text,
  name        text,
  role        text not null default 'viewer' check (role in ('admin','editor','viewer')),
  created_at  timestamptz not null default now()
);

-- Nível do usuário autenticado (security definer evita recursão nas policies)
create or replace function public.my_role()
returns text
language sql stable security definer set search_path = public as $$
  select role from public.profiles where id = auth.uid()
$$;

-- Toda conta nova ganha um perfil. A primeira conta do sistema vira administradora.
create or replace function public.handle_new_user()
returns trigger
language plpgsql security definer set search_path = public as $$
declare first_user boolean;
begin
  select not exists (select 1 from public.profiles) into first_user;
  insert into public.profiles (id, email, name, role)
  values (new.id, new.email, coalesce(new.raw_user_meta_data->>'name', split_part(new.email,'@',1)),
          case when first_user then 'admin' else 'viewer' end)
  on conflict (id) do nothing;
  return new;
end $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ============================================================
-- 2. Documentos do sistema (config, pessoas, alocações, valores mensais)
-- ============================================================
create table if not exists public.docs (
  coll        text not null check (coll in ('config','people','alloc','monthly')),
  id          text not null,
  data        jsonb not null,
  updated_at  timestamptz not null default now(),
  updated_by  uuid references auth.users(id) on delete set null,
  primary key (coll, id)
);

-- ============================================================
-- 3. Regras de acesso (RLS) — aplicadas pelo servidor
-- ============================================================
alter table public.profiles enable row level security;
alter table public.docs     enable row level security;

drop policy if exists "profiles: ver o próprio"           on public.profiles;
drop policy if exists "profiles: admin vê todos"          on public.profiles;
drop policy if exists "profiles: admin altera"            on public.profiles;
drop policy if exists "profiles: editar o próprio nome"   on public.profiles;

create policy "profiles: ver o próprio"         on public.profiles for select using (id = auth.uid());
create policy "profiles: admin vê todos"        on public.profiles for select using (public.my_role() = 'admin');
create policy "profiles: admin altera"          on public.profiles for update using (public.my_role() = 'admin') with check (public.my_role() = 'admin');

drop policy if exists "docs: leitura autenticada"  on public.docs;
drop policy if exists "docs: escrita por nível"    on public.docs;
drop policy if exists "docs: alteração por nível"  on public.docs;
drop policy if exists "docs: exclusão por nível"   on public.docs;

-- Leitura: qualquer usuário autenticado (Leitura, Editor, Administrador)
create policy "docs: leitura autenticada" on public.docs for select using (auth.role() = 'authenticated');

-- Escrita: administrador em tudo; editor só em alocações e valores mensais
create policy "docs: escrita por nível" on public.docs for insert
  with check (public.my_role() = 'admin' or (public.my_role() = 'editor' and coll in ('alloc','monthly')));
create policy "docs: alteração por nível" on public.docs for update
  using      (public.my_role() = 'admin' or (public.my_role() = 'editor' and coll in ('alloc','monthly')))
  with check (public.my_role() = 'admin' or (public.my_role() = 'editor' and coll in ('alloc','monthly')));
create policy "docs: exclusão por nível" on public.docs for delete
  using (public.my_role() = 'admin');

-- ============================================================
-- 4. Atualização em tempo real (quem está com a página aberta vê as mudanças)
-- ============================================================
alter table public.docs     replica identity full;
alter table public.profiles replica identity full;
do $$ begin
  alter publication supabase_realtime add table public.docs;
exception when duplicate_object then null; end $$;
do $$ begin
  alter publication supabase_realtime add table public.profiles;
exception when duplicate_object then null; end $$;
