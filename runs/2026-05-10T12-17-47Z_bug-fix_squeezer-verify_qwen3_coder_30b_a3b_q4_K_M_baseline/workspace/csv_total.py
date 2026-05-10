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
        try:
            next(reader)  # Skip header row
        except StopIteration:
            # Empty file - no header to skip
            return 0
        for row in reader:
            try:
                s += int(row[1])
            except (ValueError, IndexError):
                # Skip rows with non-numeric values or missing columns
                pass
    return s


if __name__ == "__main__":
    print(total(sys.argv[1]))