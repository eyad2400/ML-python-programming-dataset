-- Data migration script from legacy shared tables into secure standalone schemas.
-- Run after creating the new database with unified-database-schema.sql

begin;

-- If legacy tables exist in public schema, migrate users first.
insert into identity.users (id, username, corporate_email, full_name, password_hash, is_active, created_at, updated_at)
select
  u.id,
  u.username,
  u.corporate_email,
  coalesce(u.full_name, u.username, split_part(u.corporate_email, '@', 1)),
  coalesce(u.password_hash, crypt(gen_random_uuid()::text, gen_salt('bf'))),
  coalesce(u.is_active, true),
  coalesce(u.created_at, now()),
  coalesce(u.updated_at, now())
from public.users u
on conflict (id) do update
set
  username = excluded.username,
  corporate_email = excluded.corporate_email,
  full_name = excluded.full_name,
  is_active = excluded.is_active,
  updated_at = now();

insert into identity.user_roles (user_id, role_id, updated_at, updated_by)
select ur.user_id, ur.role_id, coalesce(ur.updated_at, now()), ur.updated_by
from public.user_roles ur
on conflict (user_id, role_id) do update
set updated_at = excluded.updated_at,
    updated_by = excluded.updated_by;

insert into audit.app_access_log (id, user_id, app_name, action, metadata, created_at)
select l.id, l.user_id, l.app_name, l.action, l.metadata, coalesce(l.created_at, now())
from public.app_access_log l
on conflict (id) do nothing;

insert into roster.records (id, payload, created_by, created_at, updated_at)
select r.id, r.payload, r.created_by, coalesce(r.created_at, now()), coalesce(r.updated_at, now())
from public.roster_records r
on conflict (id) do update
set payload = excluded.payload,
    updated_at = excluded.updated_at;

insert into vda.vehicle_records (id, payload, created_by, created_at, updated_at)
select v.id, v.payload, v.created_by, coalesce(v.created_at, now()), coalesce(v.updated_at, now())
from public.vda_vehicle_records v
on conflict (id) do update
set payload = excluded.payload,
    updated_at = excluded.updated_at;

insert into hrms.records (id, payload, created_by, created_at, updated_at)
select h.id, h.payload, h.created_by, coalesce(h.created_at, now()), coalesce(h.updated_at, now())
from public.hrms_records h
on conflict (id) do update
set payload = excluded.payload,
    updated_at = excluded.updated_at;

commit;
