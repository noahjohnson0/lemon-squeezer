import sqlite3
from flask import Flask, request, jsonify

app = Flask(__name__)
DATABASE = 'users.db'

def get_db_connection():
    conn = sqlite3.connect(DATABASE)
    conn.row_factory = sqlite3.Row
    return conn

@app.route('/lookup', methods=['GET'])
def lookup_user():
    name = request.args.get('name')
    if not name:
        return jsonify({'error': 'Name parameter is required'}), 400

    con = get_db_connection()
    user = lookup(con, name)
    con.close()

    if user is None:
        return jsonify({'error': 'User not found'}), 404
    else:
        return jsonify({
            'id': user['id'],
            'name': user['name']
        })

def lookup(con, name):
    cursor = con.cursor()
    query = "SELECT * FROM users WHERE name = ?"
    cursor.execute(query, (name,))
    row = cursor.fetchone()
    return dict(row) if row else None

if __name__ == '__main__':
    app.run(debug=True)
