import sqlite3
from http.server import BaseHTTPRequestHandler, HTTPServer

def lookup(con, name):
    cur = con.cursor()
    cur.execute("SELECT * FROM users WHERE name = ?", (name,))
    return cur.fetchone()

class RequestHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        name = self.path.split("/")[-1]
        con = sqlite3.connect("users.db")
        user = lookup(con, name)
        con.close()

        if user:
            self.send_response(200)
            self.send_header("Content-type", "text/plain")
            self.end_headers()
            self.wfile.write(f"Found: {user[0]} {user[1]}".encode())
        else:
            self.send_response(404)
            self.send_header("Content-type", "text/plain")
            self.end_headers()
            self.wfile.write(b"User not found")

def run(server_class=HTTPServer, handler_class=RequestHandler, port=8000):
    server_address = ("", port)
    httpd = server_class(server_address, handler_class)
    print(f"Starting server on port {port}...")
    httpd.serve_forever()

if __name__ == "__main__":
    run()
