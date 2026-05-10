#!/usr/bin/env python3
"""
Test for SQL injection fix in user lookup
This would be a test file for the fix that was requested
"""

import sys
import os

# Add current directory to path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from app import init_db, lookup

def test_normal_lookup():
    """Test that normal user lookups work correctly"""
    db = init_db()
    result = lookup(db, "alice")
    assert len(result) == 1
    assert result[0][1] == "alice"  # name field
    assert result[0][2] == "alice@example.com"  # email field
    print("✓ Normal lookup works")

def test_empty_lookup():
    """Test lookup with empty string"""
    db = init_db()
    result = lookup(db, "")
    assert len(result) == 0
    print("✓ Empty lookup works")

def test_nonexistent_user():
    """Test lookup with non-existent user"""
    db = init_db()
    result = lookup(db, "david")
    assert len(result) == 0
    print("✓ Non-existent user lookup works")

def test_sql_injection_prevention():
    """Test that SQL injection attempts are properly handled"""
    db = init_db()
    
    # Test malicious input that would break a vulnerable query
    malicious_input = "alice'); DROP TABLE users; --"
    result = lookup(db, malicious_input)
    assert len(result) == 0  # Should not return any results
    
    # Test another injection attempt
    malicious_input2 = "'; SELECT * FROM users WHERE '1'='1"
    result = lookup(db, malicious_input2)
    assert len(result) == 0  # Should not return any results
    
    print("✓ SQL injection prevention works")

def test_special_characters():
    """Test that special characters in usernames work correctly"""
    db = init_db()
    
    # Test username with special characters
    result = lookup(db, "alice@example.com")
    assert len(result) == 0  # Should not match any users
    
    print("✓ Special characters handled correctly")

def run_all_tests():
    """Run all tests"""
    print("Running SQL injection fix tests...")
    test_normal_lookup()
    test_empty_lookup()
    test_nonexistent_user()
    test_sql_injection_prevention()
    test_special_characters()
    print("All tests passed! ✓")

if __name__ == "__main__":
    run_all_tests()