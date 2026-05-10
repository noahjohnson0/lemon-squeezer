import csv
import sys

def sum_amounts(filename):
    total = 0
    try:
        with open(filename, newline='') as csvfile:
            reader = csv.DictReader(csvfile)
            for row in reader:
                try:
                    amount = int(row['amount'])
                    total += amount
                except ValueError:
                    # Silently ignore rows with invalid integers
                    continue
    except FileNotFoundError:
        print(f"File {filename} not found.")
        sys.exit(1)

    return total

if __name__ == '__main__':
    if len(sys.argv) != 2:
        print("Usage: python csv_total.py <filename>")
        sys.exit(1)

    filename = sys.argv[1]
    result = sum_amounts(filename)
    print(result)
