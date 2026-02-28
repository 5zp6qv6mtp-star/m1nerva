# Minerva Self-Hosting

This setup runs the site and a local SQLite-backed API on the same server.

## Start server

```bash
cd "/Users/dylanyoung/Documents/New project/minerva"
python3 server.py
```

Default URL: `http://127.0.0.1:8080`

## What it provides

- Static site files
- `GET /rest/v1/links` (read links)
- `POST /rest/v1/links` (insert links)
- SQLite database file: `minerva.db`

## Change host/port

```bash
MINERVA_HOST=0.0.0.0 MINERVA_PORT=8080 python3 server.py
```

## Test API quickly

```bash
curl "http://127.0.0.1:8080/rest/v1/links?section=eq.%2Ffiles%2F"
```

```bash
curl -X POST "http://127.0.0.1:8080/rest/v1/links" \
  -H "Content-Type: application/json" \
  --data '[{"section":"/files/","name":"Test","direct_url":"https://example.com/file.zip"}]'
```
