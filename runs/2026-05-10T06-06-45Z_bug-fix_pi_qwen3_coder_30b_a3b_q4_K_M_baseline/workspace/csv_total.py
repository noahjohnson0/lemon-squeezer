import csv
import sys


def total(path):
    s = 0
    with open(path) as f:
        reader = csv.reader(f)
        next(reader)  # Skip header row
        for row in reader:
            try:
                s += int(row[1])
            except (ValueError, IndexError):
                # Silently ignore rows with non-numeric amount or missing amount
                pass
    return s


if __name__ == "__main__":
    print(total(sys.argv[1]))