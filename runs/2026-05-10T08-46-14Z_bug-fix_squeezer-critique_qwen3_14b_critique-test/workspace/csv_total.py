import csv
import sys

def total(path):
    s = 0
    skip_header = True
    with open(path) as f:
        for row in csv.reader(f):
            if skip_header:
                skip_header = False
                continue
            try:
                s += int(row[1])
            except (ValueError, IndexError):
                pass
    return s

if __name__ == "__main__":
    print(total(sys.argv[1]))