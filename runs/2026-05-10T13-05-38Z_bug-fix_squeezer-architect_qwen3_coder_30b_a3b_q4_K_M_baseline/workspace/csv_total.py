"""Sum the 'amount' column of a CSV file.

Usage: python csv_total.py <path>

Currently broken: crashes on the header row and on any non-numeric value.
"""
import csv
import sys


def total(path):
    total = 0
    with open(path) as f:
        reader = csv.DictReader(f)
        for row in reader:
            try:
                amt = int(row['amount'])
                total += amt
            except (ValueError, KeyError):
                # silently ignore rows with missing or non-integer amount
                continue
    return total


if __name__ == "__main__":
    print(total(sys.argv[1]))