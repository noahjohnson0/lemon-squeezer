import unittest
from app import lookup

class TestApp(unittest.TestCase):
    
    def test_normal_lookup(self):
        """Test that normal lookups work correctly"""
        result = lookup("alice")
        self.assertEqual(len(result), 1)
        self.assertEqual(result[0][1], "alice")
        
    def test_injection_prevention(self):
        """Test that injection payloads are properly handled"""
        result = lookup("' OR '1'='1")
        self.assertEqual(len(result), 0)
        
    def test_edge_cases(self):
        """Test edge cases like empty strings and special characters"""
        result = lookup("")
        self.assertEqual(len(result), 0)
        
        result = lookup("alice's")
        self.assertEqual(len(result), 0)
        
    def test_parameterized_query(self):
        """Test that the query is actually parameterized (not vulnerable)"""
        # This should return 0 rows, not 1 (which would happen with injection)
        result = lookup("alice' OR '1'='1")
        self.assertEqual(len(result), 0)

if __name__ == '__main__':
    unittest.main()