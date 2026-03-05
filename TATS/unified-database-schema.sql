-- Unified standalone PostgreSQL schema for ecosystem-app.html
-- Consolidates storage for Roster + VDA + HRMS and a shared admin login model.

begin;

create extension if not exists pgcrypto;

create schema if not exists identity;
create schema if not exists roster;
create schema if not exists vda;
create schema if not exists hrms;
create schema if not exists audit;
create schema if not exists migration;

-- =========================
-- Identity / shared login
-- =========================
create table if not exists identity.users (
  id uuid primary key default gen_random_uuid(),
  username text unique not null,
  corporate_email text unique,
  full_name text,
  password_hash text not null,
  legacy_password text,
  role text not null default 'user' check (role in ('admin','editor','operator','user','viewer')),
  source_app text not null default 'ecosystem' check (source_app in ('ecosystem','roster','vda','hrms')),
  tab_privileges jsonb not null default '[]'::jsonb,
  is_active boolean not null default true,
  must_change_password boolean not null default false,
  failed_attempts int not null default 0,
  locked_until timestamptz,
  last_login_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists identity.sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references identity.users(id) on delete cascade,
  access_token_hash text not null,
  refresh_token_hash text,
  issued_at timestamptz not null default now(),
  expires_at timestamptz not null,
  revoked_at timestamptz,
  ip_address inet,
  user_agent text
);

create table if not exists identity.user_app_access (
  user_id uuid not null references identity.users(id) on delete cascade,
  app_code text not null check (app_code in ('roster','vda','hrms')),
  can_access boolean not null default true,
  updated_at timestamptz not null default now(),
  primary key (user_id, app_code)
);

-- =========================
-- Roster domain
-- =========================
create table if not exists roster.departments (
  id bigserial primary key,
  name text not null,
  group_key text,
  created_at timestamptz not null default now()
);

create table if not exists roster.ranks (
  id bigserial primary key,
  name text not null unique,
  sort_order int not null default 0
);

create table if not exists roster.job_titles (
  id bigserial primary key,
  name text not null unique
);

create table if not exists roster.officers (
  id bigserial primary key,
  name text not null,
  rank_id bigint references roster.ranks(id),
  badge text,
  department_id bigint references roster.departments(id),
  job_title_id bigint references roster.job_titles(id),
  is_active boolean not null default true,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists roster.monthly_assignments (
  id bigserial primary key,
  assignment_month date not null,
  officer_id bigint not null references roster.officers(id) on delete cascade,
  day_date date not null,
  duty_name text not null,
  notes text,
  created_by uuid references identity.users(id),
  created_at timestamptz not null default now(),
  unique (officer_id, day_date, duty_name)
);

-- =========================
-- VDA domain
-- =========================
create table if not exists vda.vehicles (
  id bigserial primary key,
  plate_no text unique not null,
  model text,
  category text,
  status text not null default 'available',
  unit text,
  odometer numeric(12,2),
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists vda.drivers (
  id bigserial primary key,
  full_name text not null,
  national_id text,
  phone text,
  license_no text,
  license_expiry date,
  status text not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists vda.vehicle_transactions (
  id bigserial primary key,
  vehicle_id bigint not null references vda.vehicles(id) on delete cascade,
  driver_id bigint references vda.drivers(id),
  transaction_type text not null,
  transaction_date timestamptz not null default now(),
  destination text,
  quantity numeric(12,2),
  notes text,
  created_by uuid references identity.users(id)
);

-- =========================
-- HRMS domain
-- =========================
create table if not exists hrms.employees (
  id bigserial primary key,
  employee_code text unique,
  full_name text not null,
  rank_name text,
  department text,
  phone text,
  email text,
  status text not null default 'active',
  hire_date date,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists hrms.training_records (
  id bigserial primary key,
  employee_id bigint not null references hrms.employees(id) on delete cascade,
  course_name text not null,
  provider text,
  start_date date,
  end_date date,
  result text,
  notes text,
  created_at timestamptz not null default now()
);

create table if not exists hrms.leave_requests (
  id bigserial primary key,
  employee_id bigint not null references hrms.employees(id) on delete cascade,
  leave_type text not null,
  start_date date not null,
  end_date date not null,
  status text not null default 'pending',
  reason text,
  approved_by uuid references identity.users(id),
  created_at timestamptz not null default now()
);

-- =========================
-- Migration staging (from 3 legacy apps)
-- =========================
create table if not exists migration.roster_legacy_dump (
  id bigserial primary key,
  source_file text not null default 'Roster-Codex14.html',
  payload jsonb not null,
  imported_at timestamptz not null default now()
);

create table if not exists migration.vda_legacy_dump (
  id bigserial primary key,
  source_file text not null default 'VDA.html',
  payload jsonb not null,
  imported_at timestamptz not null default now()
);

create table if not exists migration.hrms_legacy_dump (
  id bigserial primary key,
  source_file text not null default 'HRMS-Codex.html',
  payload jsonb not null,
  imported_at timestamptz not null default now()
);

create table if not exists audit.activity_log (
  id bigserial primary key,
  user_id uuid references identity.users(id),
  app_code text,
  action text not null,
  metadata jsonb,
  created_at timestamptz not null default now()
);

create or replace function identity.touch_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end $$;

create trigger trg_identity_users_updated before update on identity.users
for each row execute function identity.touch_updated_at();
create trigger trg_roster_officers_updated before update on roster.officers
for each row execute function identity.touch_updated_at();
create trigger trg_vda_vehicles_updated before update on vda.vehicles
for each row execute function identity.touch_updated_at();
create trigger trg_vda_drivers_updated before update on vda.drivers
for each row execute function identity.touch_updated_at();
create trigger trg_hrms_employees_updated before update on hrms.employees
for each row execute function identity.touch_updated_at();

create index if not exists idx_users_role on identity.users(role);
create index if not exists idx_user_app_access_app on identity.user_app_access(app_code);
create index if not exists idx_roster_assignments_month on roster.monthly_assignments(assignment_month);
create index if not exists idx_vda_transactions_date on vda.vehicle_transactions(transaction_date desc);
create index if not exists idx_hrms_leave_status on hrms.leave_requests(status);

commit;
