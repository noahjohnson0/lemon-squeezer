import sqlite3

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
    return con

def lookup(name):
    con = init_db()
    cur = con.cursor()
    # FIXED: Using parameterized query instead of string interpolation
    cur.execute("SELECT id, name, email FROM users WHERE name = ?", (name,))
    return cur.fetchall()