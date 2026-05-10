"""Sum the 'amount' column of a CSV file.

Usage: python csv_total.py <path>

Currently broken: crashes on the header row and on any non-numeric value.
"""
import csv
import sys


def total(path):
    s = 0
    with open(path) as f:
        for row in csv.reader(f):
            s += int(row[1])
    return s


if __name__ == "__main__":
    print(total(sys.argv[1]))
