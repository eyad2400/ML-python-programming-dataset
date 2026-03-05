# ML-python-programming-dataset

create a ML python programming dataset

## Unified General Assistance Ecosystem App

A secure integrated entry point is provided in `/TATS`:

- `ecosystem-app.html` → unified login shell + admin dashboard for:
  - `Roster-Codex14.html`
  - `VDA.html`
  - `HRMS-Codex.html`
- `app-config.example.json` → backend config template for real API auth.
- `unified-database-schema.sql` → hardened standalone PostgreSQL schema with separate app schemas and RLS.
- `migrate-to-standalone-db.sql` → migration script for moving legacy data into the new secure schemas.

### Run locally

```bash
cd TATS
python3 -m http.server 8000
```

Then open:

- `http://localhost:8000/ecosystem-app.html`

### Real authentication / secure backend requirements

1. Copy `app-config.example.json` to `app-config.json`.
2. For local development, run your API on `http://localhost:8001` (default in `app-config.example.json`) or update endpoints to your deployed HTTPS API.
3. Implement backend endpoints:
   - `POST /auth/login` (returns JWT access token + optional refresh token)
   - `GET /me`
   - `GET /permissions`
   - `GET /admin/users`
   - `POST /admin/roles`

### Database hardening and migration

1. Provision a dedicated PostgreSQL instance for this ecosystem (not shared with other systems).
2. Apply `unified-database-schema.sql`.
3. Run `migrate-to-standalone-db.sql` from old database exports/tables.
4. Rotate credentials and restrict direct table access to backend service roles only.