#!/usr/bin/env python3
"""
Demonstration that shows the SQL injection vulnerability concept
"""

def show_fix_approach():
    print("SQL Injection Fix Demonstration:")
    print("=" * 40)
    print()
    
    print("VULNERABLE CODE (original approach):")
    print("  query = f\"SELECT * FROM users WHERE name = '{name}'\"")
    print("  cur.execute(query)")
    print("  # This allows: \"alice'; DROP TABLE users; --\"")
    print()
    
    print("FIXED CODE (parameterized approach):")
    print("  cur.execute(\"SELECT * FROM users WHERE name = ?\", (name,))")
    print("  # This prevents injection attacks")
    print()
    
    print("Why this works:")
    print("- The parameterized query treats the input as data, not as SQL code")
    print("- Even malicious input like \"'; SELECT * FROM users WHERE '1'='1\"")
    print("  gets treated as a literal string, not as executable SQL")
    print()
    
    print("The fix ensures that:")
    print("✓ Regular queries work normally")
    print("✓ SQL injection attempts return no results")
    print("✓ Database integrity is maintained")

if __name__ == "__main__":
    show_fix_approach()