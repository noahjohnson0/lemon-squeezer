#!/usr/bin/env python3
"""Simple test to verify the fix works correctly"""

import sys
sys.path.insert(0, '/Users/noahjohnson0/repos/lemon-squeezer/runs/2026-05-10T11-40-01Z_sql-injection-fix_squeezer-tdd_qwen3_coder_30b_a3b_q4_K_M_baseline/workspace')

from app import init_db, lookup

def test_fix():
    # Initialize database
    db = init_db()
    
    # Test normal lookup
    result = lookup(db, "alice")
    print(f"Lookup 'alice': {result}")
    assert len(result) == 1
    assert result[0][1] == "alice"
    
    # Test injection attempt - should return empty result
    result = lookup(db, "alice'); DROP TABLE users; --")
    print(f"Lookup with injection attempt: {result}")
    assert len(result) == 0
    
    # Test injection attempt with actual malicious input
    result = lookup(db, "'; SELECT * FROM users WHERE '1'='1")
    print(f"Lookup with different injection attempt: {result}")
    assert len(result) == 0
    
    print("All tests passed!")

if __name__ == "__main__":
    test_fix()