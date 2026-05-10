"""Sum the 'amount' column of a CSV file.

Usage: python csv_total.py <path>

Currently broken: crashes on the header row and on any non-numeric value.
"""
import csv
import sys


def total(path):
    s = 0
    with open(path, newline='') as f:
        reader = csv.reader(f)
        next(reader, None)  # skip header
        for row in reader:
            if len(row) < 2:
                continue
            try:
                s += int(row[1])
            except ValueError:
                pass
    return s


if __name__ == "__main__":
    print(total(sys.argv[1]))
