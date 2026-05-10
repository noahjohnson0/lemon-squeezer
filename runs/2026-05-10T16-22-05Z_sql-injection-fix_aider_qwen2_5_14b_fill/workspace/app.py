import http.server
import socketserver
import sqlite3

PORT = 8000

def init_db():
    con = sqlite3.connect(":memory:")
    cur = con.cursor()
    cur.execute("CREATE TABLE users (name TEXT, age INTEGER)")
    cur.executemany("INSERT INTO users VALUES (?, ?)", [("alice", 25), ("bob", 30)])
    return con

def lookup(con, name):
    cur = con.cursor()
    # Use parameterized query to prevent SQL injection
    cur.execute("SELECT * FROM users WHERE name=?", (name,))
    return cur.fetchall()

class RequestHandler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/lookup':
            name = self.headers['name']
            rows = lookup(con, name)
            response = '\n'.join([f"{row[0]}, {row[1]}" for row in rows])
            self.send_response(200)
            self.end_headers()
            self.wfile.write(response.encode('utf-8'))
        else:
            super().do_GET()

if __name__ == '__main__':
    con = init_db()
    with socketserver.TCPServer(("", PORT), RequestHandler) as httpd:
        print(f"Serving on port {PORT}")
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            pass
