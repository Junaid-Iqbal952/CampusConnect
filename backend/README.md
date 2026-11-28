# CampusConnect backend (FastAPI)

## First-time setup (Windows, from the `backend` folder)

```bash
python -m venv venv
venv\Scripts\activate            # Mac/Linux: source venv/bin/activate
pip install -r requirements.txt
copy .env.example .env           # Mac/Linux: cp .env.example .env
```

If PowerShell says *"running scripts is disabled on this system"* when activating, run this once and try again:
`Set-ExecutionPolicy -Scope CurrentUser RemoteSigned`

Open `.env` and paste the real `DATABASE_URL` (Supabase → Connect → Transaction pooler)
and the team's shared `JWT_SECRET`.

## Run the server

```bash
venv\Scripts\activate
uvicorn main:app --reload
```

- http://127.0.0.1:8000 → should say "database is connected"
- http://127.0.0.1:8000/docs → try `/auth/signup` and `/auth/login` in the browser

## Run the tests

```bash
pytest -v
```

Tests use a temporary in-memory database, so they don't need Supabase and never touch real data.

## Auth endpoints

| Method | Path | Body | Success | Errors (`{"detail": "..."}`) |
|---|---|---|---|---|
| POST | `/auth/signup` | `name, erp, email, password` | 201 `{token, user}` | 400 invalid field, 409 ERP/email already used |
| POST | `/auth/login` | `identifier` (ERP or email), `password` | 200 `{token, user}` | 401 `Wrong username or password` |
| POST | `/auth/change-password` | `erp, current_password, new_password` + header `Authorization: Bearer <token>` | 200 `{message}` | 400 wrong ERP/current password, too short, or same as current; 401 not logged in / logged in on another device |
| POST | `/listings` | form: `title, description, hourly_rate, condition, max_duration (days), negotiable, campus (Main/City), photo (jpg/png)` + header `Authorization: Bearer <token>` | 201 `{message, data}` | 400 invalid field or photo, 401 not logged in, 502 photo upload failed |
| GET | `/listings/mine` | header `Authorization: Bearer <token>` | 200 `{data: {items}}` (your own listings, newest first, each with `status`) | 401 not logged in |
| PUT | `/listings/{id}` | same form as POST, but `photo` is optional (leave it out to keep the old photo) + header `Authorization: Bearer <token>` | 200 `{message, data}` | 400 invalid field or photo, 401 not logged in, 403 not your listing, 404 no such listing, 409 listing not available, 502 photo upload failed |