"""A vulnerable user-lookup endpoint. Has a classic SQL injection bug.

Run: python3 app.py  -> serves on http://127.0.0.1:8765/user?name=foo
"""
import sqlite3
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.parse import urlparse, parse_qs


def init_db():
    con = sqlite3.connect(":memory:", check_same_thread=False)
    cur = con.cursor()
    cur.execute("CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT, email TEXT, ssn TEXT)")
    cur.executemany(
        "INSERT INTO users (name, email, ssn) VALUES (?, ?, ?)",
        [
            ("alice", "alice@example.com", "111-11-1111"),
            ("bob",   "bob@example.com",   "222-22-2222"),
            ("carol", "carol@example.com", "333-33-3333"),
        ],
    )
    con.commit()
    return con


def lookup(con, name):
    cur = con.cursor()
    # FIXED: using parameterized query to prevent SQL injection
    q = "SELECT id, name, email FROM users WHERE name = ?"
    cur.execute(q, (name,))
    return cur.fetchall()


class Handler(BaseHTTPRequestHandler):
    db = None

    def do_GET(self):
        u = urlparse(self.path)
        if u.path != "/user":
            self.send_response(404); self.end_headers(); return
        qs = parse_qs(u.query)
        name = qs.get("name", [""])[0]
        try:
            rows = lookup(self.db, name)
        except Exception as e:
            self.send_response(500); self.end_headers()
            self.wfile.write(f"error: {e}".encode())
            return
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        import json
        self.wfile.write(json.dumps(rows).encode())

    def log_message(self, *a, **kw):  # silence
        pass


def main():
    Handler.db = init_db()
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8765
    srv = HTTPServer(("127.0.0.1", port), Handler)
    srv.serve_forever()


if __name__ == "__main__":
    main()
