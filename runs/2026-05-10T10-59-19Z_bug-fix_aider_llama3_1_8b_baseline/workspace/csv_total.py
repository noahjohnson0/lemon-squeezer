import csv

def total_amount(filename):
    with open(filename, 'r') as file:
        reader = csv.DictReader(file)
        total = 0
        for row in reader:
            try:
                amount = int(row['amount'])
                total += amount
            except ValueError:
                pass
        return total

print(total_amount('data.csv'))
