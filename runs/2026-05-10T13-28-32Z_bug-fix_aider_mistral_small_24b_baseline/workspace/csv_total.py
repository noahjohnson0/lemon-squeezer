import csv
import sys

def main(filename):
    total = 0
    with open(filename, newline='') as csvfile:
        reader = csv.DictReader(csvfile)
        for row in reader:
            try:
                amount = int(row['amount'])
                total += amount
            except ValueError:
                # Ignore rows where 'amount' is not a valid integer
                continue
    print(total)

if __name__ == '__main__':
    if len(sys.argv) != 2:
        print("Usage: python csv_total.py <filename>")
        sys.exit(1)
    main(sys.argv[1])
