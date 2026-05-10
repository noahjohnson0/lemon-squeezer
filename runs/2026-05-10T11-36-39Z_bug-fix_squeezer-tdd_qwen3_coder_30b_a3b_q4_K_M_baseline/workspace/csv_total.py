"""Sum the 'amount' column of a CSV file.

Usage: python csv_total.py <path>

Currently broken: crashes on the header row and on any non-numeric value.
"""
import csv
import sys


def total(path):
    s = 0
    with open(path) as f:
        reader = csv.reader(f)
        # Skip the header row
        try:
            next(reader)
        except StopIteration:
            # Empty file
            return 0
            
        for row in reader:
            # Skip rows that don't have enough columns
            if len(row) < 2:
                continue
            try:
                # Try to convert the amount to int, skip if it fails
                amount = int(row[1])
                s += amount
            except (ValueError, TypeError):
                # Silently ignore non-numeric values
                continue
    return s


if __name__ == "__main__":
    print(total(sys.argv[1]))