import csv
import sys
import os
from csv_total import total

def test_happy_path():
    """Test the basic functionality with the given data.csv"""
    # This should sum 10 + 20 + 30 + 40 = 100
    result = total('data.csv')
    assert result == 100, f"Expected 100, got {result}"
    print("Happy path test passed!")

def test_simple_case():
    """Test with a simple CSV that has valid numbers"""
    # Create a simple test case
    test_data = [
        ['name', 'amount'],
        ['item1', '10'],
        ['item2', '20'],
        ['item3', '30']
    ]
    
    with open('simple_test.csv', 'w', newline='') as f:
        writer = csv.writer(f)
        writer.writerows(test_data)
    
    result = total('simple_test.csv')
    assert result == 60, f"Expected 60, got {result}"
    print("Simple case test passed!")

if __name__ == "__main__":
    test_happy_path()
    test_simple_case()
    print("All tests passed!")