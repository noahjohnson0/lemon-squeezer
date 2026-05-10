orders = [
    {
        'customer': 'alice',
        'items': [
            {'name': 'apple', 'price': 1.5, 'quantity': 2},
            {'name': 'banana', 'price': 2.0, 'quantity': 1},
            {'name': 'cookie', 'price': 1.0, 'quantity': 3}
        ]
    },
    {
        'customer': 'bob',
        'items': [
            {'name': 'apple', 'price': 1.5, 'quantity': 1},
            {'name': 'banana', 'price': 2.0, 'quantity': 5},
            {'name': 'cookie', 'price': 1.0, 'quantity': 2},
            {'name': 'donut', 'price': 2.5, 'quantity': 2}
        ]
    },
    {
        'customer': 'carol',
        'items': [
            {'name': 'apple', 'price': 1.5, 'quantity': 1},
            {'name': 'cookie', 'price': 1.0, 'quantity': 1}
        ]
    }
]

def customer_total(order):
    total = 0.0
    for item in order['items']:
        total += item['price'] * item['quantity']
    return total

for order in orders:
    print(f"{order['customer']} paid {customer_total(order)}")

grand_total = sum(customer_total(o) for o in orders)
print(f"grand total {grand_total}")
