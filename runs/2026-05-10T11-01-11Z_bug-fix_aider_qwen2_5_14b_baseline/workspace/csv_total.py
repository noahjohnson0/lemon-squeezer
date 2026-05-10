import csv

def total_amount(filename):
    with open(filename) as f:
        reader = csv.DictReader(f)
        total = 0
        for row in reader:
            try:
                amount = int(row['amount'])
                total += amount
            except ValueError:
                continue
    print(total)

if __name__ == '__main__':
    import sys
    if len(sys.argv) != 2:
        print(f"Usage: {sys.argv[0]} filename.csv")
        sys.exit(1)
    total_amount(sys.argv[1])
