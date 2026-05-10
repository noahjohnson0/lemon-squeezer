def customer_total(order):
    total = 0.0
    for item in order['items']:
        total += item['price'] * item['quantity']
    return total

orders = [
    {
        'name': 'alice',
        'items': [
            {'name': 'apple', 'price': 1.5, 'quantity': 2},
            {'name': 'banana', 'price': 0.75, 'quantity': 3}
        ]
    },
    {
        'name': 'bob',
        'items': [
            {'name': 'orange', 'price': 2.0, 'quantity': 4},
            {'name': 'grape', 'price': 1.5, 'quantity': 6}
        ]
    },
    {
        'name': 'carol',
        'items': [
            {'name': 'pear', 'price': 3.0, 'quantity': 1}
        ]
    }
]

for order in orders:
    print(f"{order['name']} paid {customer_total(order)}")

grand_total = sum(customer_total(o) for o in orders)
print(f"grand total {grand_total}")
