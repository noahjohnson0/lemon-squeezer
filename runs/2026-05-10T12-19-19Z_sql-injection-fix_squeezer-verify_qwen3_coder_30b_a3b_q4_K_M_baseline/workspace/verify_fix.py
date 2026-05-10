#!/usr/bin/env python3
"""Verify the SQL injection fix works correctly"""

import sys
import os
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from app import lookup, init_db

def demonstrate_fix():
    print("Testing SQL injection fix...")
    
    # Test 1: Normal functionality should work
    print("\n1. Testing normal lookups:")
    result = lookup("alice")
    print(f"   lookup('alice') -> {len(result)} rows")
    assert len(result) == 1
    assert result[0][1] == "alice"
    print("   ✓ Normal lookup works")
    
    # Test 2: Injection payload should return 0 rows (the fix)
    print("\n2. Testing SQL injection prevention:")
    injection_payload = "' OR '1'='1"
    result = lookup(injection_payload)
    print(f"   lookup(\"'{injection_payload}\") -> {len(result)} rows")
    assert len(result) == 0
    print("   ✓ Injection payload properly handled")
    
    print("\n🎉 All tests passed! The SQL injection vulnerability is fixed.")

if __name__ == "__main__":
    demonstrate_fix()