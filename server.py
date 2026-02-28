#!/usr/bin/env python3
import json
import os
import sqlite3
from datetime import datetime, timezone
from http.server import ThreadingHTTPServer, SimpleHTTPRequestHandler
from pathlib import Path
from urllib.parse import parse_qs, unquote, urlparse

ROOT = Path(__file__).resolve().parent
DB_PATH = ROOT / "minerva.db"
HOST = os.environ.get("MINERVA_HOST", "127.0.0.1")
PORT = int(os.environ.get("MINERVA_PORT", "8080"))


def db_conn():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn


def init_db():
    with db_conn() as conn:
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS links (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                section TEXT NOT NULL,
                name TEXT NOT NULL,
                direct_url TEXT,
                notes TEXT,
                size TEXT,
                date TEXT,
                created_at TEXT NOT NULL
            )
            """
        )
        conn.commit()


class MinervaHandler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(ROOT), **kwargs)

    def _send_json(self, status: int, payload):
        body = json.dumps(payload).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Headers", "Content-Type, Authorization, apikey")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.end_headers()
        self.wfile.write(body)

    def do_OPTIONS(self):
        self.send_response(204)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Headers", "Content-Type, Authorization, apikey")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.end_headers()

    def do_GET(self):
        parsed = urlparse(self.path)
        if parsed.path == "/rest/v1/links" or parsed.path == "/api/links":
            return self._get_links(parsed)
        return super().do_GET()

    def do_POST(self):
        parsed = urlparse(self.path)
        if parsed.path == "/rest/v1/links" or parsed.path == "/api/links":
            return self._post_links(parsed)
        self._send_json(404, {"error": "not_found"})

    def _get_links(self, parsed):
        qs = parse_qs(parsed.query)

        section = None
        if "section" in qs and qs["section"]:
            raw = qs["section"][0]
            if raw.startswith("eq."):
                section = unquote(raw[3:])
            else:
                section = unquote(raw)

        order = "ASC"
        if "order" in qs and qs["order"]:
            order_raw = qs["order"][0].lower()
            if order_raw.endswith(".desc"):
                order = "DESC"

        limit = None
        if "limit" in qs and qs["limit"]:
            try:
                limit = max(0, int(qs["limit"][0]))
            except ValueError:
                limit = None

        sql = "SELECT id, section, name, direct_url, notes, size, date, created_at FROM links"
        params = []
        if section is not None:
            sql += " WHERE section = ?"
            params.append(section)
        sql += f" ORDER BY created_at {order}, id {order}"
        if limit is not None:
            sql += " LIMIT ?"
            params.append(limit)

        with db_conn() as conn:
            rows = [dict(r) for r in conn.execute(sql, params).fetchall()]

        self._send_json(200, rows)

    def _post_links(self, parsed):
        length = int(self.headers.get("Content-Length", "0"))
        raw = self.rfile.read(length) if length > 0 else b"[]"

        try:
            payload = json.loads(raw.decode("utf-8"))
        except Exception:
            return self._send_json(400, {"error": "invalid_json"})

        if isinstance(payload, dict):
            payload = [payload]
        if not isinstance(payload, list):
            return self._send_json(400, {"error": "payload_must_be_array"})

        now = datetime.now(timezone.utc).isoformat()
        inserted = []

        with db_conn() as conn:
            for item in payload:
                if not isinstance(item, dict):
                    continue
                section = str(item.get("section", "")).strip() or "/files/"
                name = str(item.get("name", "")).strip() or "Untitled"
                direct_url = str(item.get("direct_url", "")).strip()
                notes = str(item.get("notes", "")).strip()
                size = str(item.get("size", "")).strip() or "-"
                date = str(item.get("date", "")).strip() or "Custom"

                cur = conn.execute(
                    """
                    INSERT INTO links (section, name, direct_url, notes, size, date, created_at)
                    VALUES (?, ?, ?, ?, ?, ?, ?)
                    """,
                    (section, name, direct_url, notes, size, date, now),
                )
                inserted.append(
                    {
                        "id": cur.lastrowid,
                        "section": section,
                        "name": name,
                        "direct_url": direct_url,
                        "notes": notes,
                        "size": size,
                        "date": date,
                        "created_at": now,
                    }
                )
            conn.commit()

        self._send_json(201, inserted)


def main():
    init_db()
    server = ThreadingHTTPServer((HOST, PORT), MinervaHandler)
    print(f"Minerva server running at http://{HOST}:{PORT}")
    print(f"Serving: {ROOT}")
    print(f"SQLite DB: {DB_PATH}")
    server.serve_forever()


if __name__ == "__main__":
    main()
