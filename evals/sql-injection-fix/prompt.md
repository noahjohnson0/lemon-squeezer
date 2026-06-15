The file `app.py` in this directory is a tiny user-lookup HTTP server. It has a **SQL-injection vulnerability** in `lookup(con, name)` - the function interpolates the `name` parameter directly into the SQL query. An attacker can pass `name=' OR '1'='1` to dump all rows.

Fix the vulnerability. Constraints:
1. Keep the `lookup(con, name)` function signature identical.
2. The fix MUST use parameterised queries (`?` placeholders + tuple). Do not just escape characters or blocklist substrings - those are wrong.
3. Normal lookups must still work: `lookup(con, "alice")` returns the alice row, `lookup(con, "bob")` returns the bob row.
4. Injection payloads must NOT return rows for users they don't match. Specifically, `lookup(con, "' OR '1'='1")` should return **0 rows** (not all 3 rows).
5. Don't change the rest of the server, the table schema, or the data.

Modify `app.py` in place. Do not run it.
