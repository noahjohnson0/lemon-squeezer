orders = [
    {
        'name': 'alice',
        'items': [
            {'price': 2.5, 'quantity': 2},
            {'price': 3.0, 'quantity': 1},
        ],
    },
    {
        'name': 'bob',
        'items': [
            {'price': 5.0, 'quantity': 3},
            {'price': 1.5, 'quantity': 1},
            {'price': 2.0, 'quantity': 2},
        ],
    },
    {
        'name': 'carol',
        'items': [
            {'price': 1.0, 'quantity': 3},
        ],
    },
]

def customer_total(order):
    return sum(item['price'] * item['quantity'] for item in order['items'])

totals = []
grand_total = 0.0

for order in orders:
    total = customer_total(order)
    totals.append((order['name'], total))
    grand_total += total

for name, total in totals:
    print(f"{name} paid {total}")

print(f"grand total {grand_total}")
