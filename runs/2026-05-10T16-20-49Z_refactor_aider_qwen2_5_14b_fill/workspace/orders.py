def customer_total(order):
    total = 0.0
    for item in order['items']:
        total += item['quantity'] * item['price']
    return total

orders = [
    {
        'customer': 'alice',
        'items': [{'product': 'eggs', 'quantity': 12}, {'product': 'milk', 'quantity': 1}]
    },
    {
        'customer': 'bob',
        'items': [{'product': 'bread', 'quantity': 2}, {'product': 'butter', 'quantity': 1}, {'product': 'eggs', 'quantity': 6}]
    },
    {
        'customer': 'carol',
        'items': [{'product': 'salad', 'quantity': 1}, {'product': 'kale', 'quantity': 1}, {'product': 'blueberries', 'quantity': 2}]
    }
]

for order in orders:
    total = customer_total(order)
    print(f"{order['customer']} paid {total}")

grand_total = sum(customer_total(o) for o in orders)
print(f"grand total {grand_total}")
