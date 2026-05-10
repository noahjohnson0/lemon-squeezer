import csv

def main(filename):
    total = 0
    with open(filename, 'r') as file:
        reader = csv.DictReader(file)
        for row in reader:
            try:
                amount = int(row['amount'])
                total += amount
            except (ValueError, KeyError):
                # Ignore rows with invalid integers or missing 'amount' field
                pass
    print(total)

if __name__ == '__main__':
    import sys
    if len(sys.argv) != 2:
        print("Usage: python csv_total.py <filename>")
    else:
        main(sys.argv[1])
