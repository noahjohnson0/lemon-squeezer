def customer_total(order):
    return sum(item['price'] for item in order['items'])

orders = [
    {'customer': 'alice', 'items': [{'price': 3.5}, {'price': 5.0}]},
    {'customer': 'bob', 'items': [{'price': 10.0}, {'price': 11.5}]},
    {'customer': 'carol', 'items': [{'price': 3.0}]},
]

for order in orders:
    total = customer_total(order)
    print(f"{order['customer']} paid {total}")

grand_total = sum(customer_total(order) for order in orders)
print(f"grand total {grand_total}")
