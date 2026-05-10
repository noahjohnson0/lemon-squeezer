import csv
import sys

def csv_total(filename):
    total = 0
    with open(filename, 'r') as file:
        reader = csv.reader(file)
        next(reader)  # Skip header row
        for row in reader:
            try:
                amount = int(row[1])  # Assuming amount is in the second column
                total += amount
            except (ValueError, IndexError):
                # Silently ignore invalid integers or missing columns
                pass
    print(total)

if __name__ == '__main__':
    csv_total(sys.argv[1])
