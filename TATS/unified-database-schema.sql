-- Unified secure database schema for:
-- تطبيق إدارة شئون الإدارة العامة للمساعدات الفنية

create extension if not exists "pgcrypto";

create table if not exists users (
  id uuid primary key default gen_random_uuid(),
  username text unique,
  corporate_email text unique not null,
  full_name text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists roles (
  id serial primary key,
  name text unique not null check (name in ('viewer', 'operator', 'admin'))
);

insert into roles(name) values ('viewer'), ('operator'), ('admin')
on conflict(name) do nothing;

create table if not exists user_roles (
  user_id uuid not null references users(id) on delete cascade,
  role_id int not null references roles(id),
  updated_at timestamptz not null default now(),
  updated_by uuid,
  primary key (user_id, role_id)
);

create table if not exists app_access_log (
  id bigserial primary key,
  user_id uuid references users(id),
  app_name text not null,
  action text not null,
  metadata jsonb,
  created_at timestamptz not null default now()
);

create table if not exists roster_records (
  id bigserial primary key,
  payload jsonb not null,
  created_by uuid references users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists vda_vehicle_records (
  id bigserial primary key,
  payload jsonb not null,
  created_by uuid references users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists hrms_records (
  id bigserial primary key,
  payload jsonb not null,
  created_by uuid references users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_users_username on users(username);
create index if not exists idx_users_corporate_email on users(corporate_email);
create index if not exists idx_app_access_log_user_time on app_access_log(user_id, created_at desc);