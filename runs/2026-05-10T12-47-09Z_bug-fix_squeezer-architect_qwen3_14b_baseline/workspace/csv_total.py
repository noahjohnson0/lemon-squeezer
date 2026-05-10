import csv
import sys

def main():
    if len(sys.argv) != 2:
        sys.exit(1)
    filename = sys.argv[1]
    total = 0
    with open(filename, newline='') as f:
        reader = csv.reader(f)
        header = next(reader, None)  # Skip header
        for row in reader:
            if not row:
                continue
            if len(row) < 2:
                continue
            try:
                amount = int(row[1].strip())
                total += amount
            except ValueError:
                # Silently ignore rows where amount is not an integer
                continue
    print(total)

if __name__ == "__main__":
    main()