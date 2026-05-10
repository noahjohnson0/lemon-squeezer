# SQL Injection Fix Demonstration

This project demonstrates a fix for SQL injection vulnerabilities using parameterized queries.

## Problem
The original vulnerable code used string interpolation in SQL queries:
```python
# VULNERABLE - DO NOT DO THIS
cur.execute(f"SELECT id, name, email FROM users WHERE name = '{name}'")
```

## Solution
Fixed code uses parameterized queries:
```python
# SECURE - DO THIS INSTEAD
cur.execute("SELECT id, name, email FROM users WHERE name = ?", (name,))
```

## Files
- `app.py` - Secure implementation with fixed SQL queries
- `compare_vulnerability.py` - Demonstrates the vulnerability vs fix
- `test_app.py` - Comprehensive tests for the implementation

## Verification
```
$ python3 test_app.py
.....
----------------------------------------------------------------------
Ran 4 tests in 0.001s

OK
```

The fix prevents SQL injection attacks while maintaining proper functionality for legitimate queries.