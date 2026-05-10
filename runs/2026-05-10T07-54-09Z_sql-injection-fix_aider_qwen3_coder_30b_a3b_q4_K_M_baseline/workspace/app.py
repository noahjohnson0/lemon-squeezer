import sqlite3
import sys

def lookup(con, name):
    # Use parameterized query to prevent SQL injection
    cursor = con.execute("SELECT * FROM users WHERE name = ?", (name,))
    return cursor.fetchall()

if __name__ == '__main__':
    con = sqlite3.connect('users.db')
    name = sys.argv[1]
    rows = lookup(con, name)
    print(rows)
    con.close()
