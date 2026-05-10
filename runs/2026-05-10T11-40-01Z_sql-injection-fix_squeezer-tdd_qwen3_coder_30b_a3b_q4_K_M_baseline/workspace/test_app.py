import sqlite3
from app import lookup, init_db

def test_normal_lookup():
    """Test that normal lookups still work"""
    con = init_db()
    
    # Test lookup for alice
    result = lookup(con, "alice")
    assert len(result) == 1
    assert result[0][1] == "alice"
    
    # Test lookup for bob
    result = lookup(con, "bob")
    assert len(result) == 1
    assert result[0][1] == "bob"

def test_injection_prevention():
    """Test that SQL injection is prevented"""
    con = init_db()
    
    # This should NOT return all rows (that's the vulnerability)
    result = lookup(con, "' OR '1'='1")
    assert len(result) == 0

def test_edge_cases():
    """Test edge cases"""
    con = init_db()
    
    # Empty string lookup
    result = lookup(con, "")
    assert len(result) == 0
    
    # Non-existent user
    result = lookup(con, "dave")
    assert len(result) == 0
    
    # Lookup with special characters
    result = lookup(con, "alice'")
    assert len(result) == 0

def test_parameterized_query():
    """Test that the query is actually using parameterized queries"""
    con = init_db()
    
    # Test with a name that would be dangerous if interpolated
    result = lookup(con, "alice'); DROP TABLE users; --")
    assert len(result) == 0

def test_round_trip():
    """Test that valid lookups work correctly"""
    con = init_db()
    
    # Get all users first
    all_users = lookup(con, "alice")
    assert len(all_users) == 1
    assert all_users[0][1] == "alice"
    
    # Then lookup again to ensure it's still working
    alice_again = lookup(con, "alice")
    assert len(alice_again) == 1
    assert alice_again[0][1] == "alice"