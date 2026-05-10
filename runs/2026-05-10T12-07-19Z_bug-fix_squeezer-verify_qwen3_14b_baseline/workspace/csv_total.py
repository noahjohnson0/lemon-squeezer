import csv

total = 0
with open('data.csv') as f:
    reader = csv.DictReader(f)
    for row in reader:
        try:
            amount = int(row['amount'])
            total += amount
        except ValueError:
            pass
print(total)