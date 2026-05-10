import csv
import sys

def total(path):
    s = 0
    with open(path) as f:
        first_row = True
        for row in csv.reader(f):
            if first_row:
                first_row = False
                continue
            if len(row) < 2:
                continue
            try:
                s += int(row[1])
            except ValueError:
                pass
    return s

if __name__ == "__main__":
    print(total(sys.argv[1]))