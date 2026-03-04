-- Standalone and secure PostgreSQL database for the unified ecosystem app
-- Covers Roster + VDA + HRMS with centralized authn/authz.

begin;

create extension if not exists pgcrypto;

create schema if not exists identity;
create schema if not exists roster;
create schema if not exists vda;
create schema if not exists hrms;
create schema if not exists audit;

create table if not exists identity.users (
  id uuid primary key default gen_random_uuid(),
  username text unique,
  corporate_email text unique not null,
  full_name text,
  password_hash text not null,
  mfa_secret text,
  is_active boolean not null default true,
  last_login_at timestamptz,
  failed_attempts int not null default 0,
  locked_until timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists identity.roles (
  id smallserial primary key,
  name text unique not null check (name in ('viewer', 'operator', 'admin'))
);

insert into identity.roles(name) values ('viewer'), ('operator'), ('admin')
on conflict(name) do nothing;

create table if not exists identity.user_roles (
  user_id uuid not null references identity.users(id) on delete cascade,
  role_id smallint not null references identity.roles(id),
  updated_at timestamptz not null default now(),
  updated_by uuid references identity.users(id),
  primary key (user_id, role_id)
);

create table if not exists identity.sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references identity.users(id) on delete cascade,
  refresh_token_hash text not null,
  issued_at timestamptz not null default now(),
  expires_at timestamptz not null,
  revoked_at timestamptz,
  ip_address inet,
  user_agent text
);

create table if not exists audit.app_access_log (
  id bigserial primary key,
  user_id uuid references identity.users(id),
  app_name text not null,
  action text not null,
  metadata jsonb,
  created_at timestamptz not null default now()
);

create table if not exists roster.records (
  id bigserial primary key,
  payload jsonb not null,
  created_by uuid references identity.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists vda.vehicle_records (
  id bigserial primary key,
  payload jsonb not null,
  created_by uuid references identity.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists hrms.records (
  id bigserial primary key,
  payload jsonb not null,
  created_by uuid references identity.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create or replace function identity.touch_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end $$;

create trigger trg_identity_users_updated_at
before update on identity.users
for each row execute function identity.touch_updated_at();

create index if not exists idx_identity_users_email on identity.users(corporate_email);
create index if not exists idx_identity_sessions_user on identity.sessions(user_id, expires_at desc);
create index if not exists idx_audit_access_user_time on audit.app_access_log(user_id, created_at desc);

-- Enforce least privilege with RLS support
alter table roster.records enable row level security;
alter table vda.vehicle_records enable row level security;
alter table hrms.records enable row level security;

create policy roster_policy on roster.records
  using (created_by = current_setting('app.current_user_id', true)::uuid)
  with check (created_by = current_setting('app.current_user_id', true)::uuid);

create policy vda_policy on vda.vehicle_records
  using (created_by = current_setting('app.current_user_id', true)::uuid)
  with check (created_by = current_setting('app.current_user_id', true)::uuid);

create policy hrms_policy on hrms.records
  using (created_by = current_setting('app.current_user_id', true)::uuid)
  with check (created_by = current_setting('app.current_user_id', true)::uuid);

commit;
