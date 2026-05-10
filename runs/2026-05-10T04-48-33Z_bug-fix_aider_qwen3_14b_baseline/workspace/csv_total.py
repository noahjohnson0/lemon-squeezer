import csv
import sys

def main():
    total = 0
    with open(sys.argv[1], 'r') as f:
        reader = csv.DictReader(f)
        for row in reader:
            try:
                total += int(row['amount'])
            except ValueError:
                continue
    print(total)

if __name__ == '__main__':
    main()
