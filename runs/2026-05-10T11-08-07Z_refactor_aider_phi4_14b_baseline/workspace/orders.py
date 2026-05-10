# orders.py

def customer_total(order):
    return sum(item['price'] * item['quantity'] for item in order['items'])

orders = [
    {'customer': 'alice', 'items': [{'name': 'apple', 'price': 1.0, 'quantity': 3}, {'name': 'banana', 'price': 2.5, 'quantity': 1}]},
    {'customer': 'bob', 'items': [{'name': 'orange', 'price': 1.5, 'quantity': 10}, {'name': 'pear', 'price': 2.0, 'quantity': 3}]},
    {'customer': 'carol', 'items': [{'name': 'grape', 'price': 3.0, 'quantity': 1}]}
]

grand_total = 0

for order in orders:
    total = customer_total(order)
    print(f"{order['customer']} paid {total}")
    grand_total += total

print(f"grand total {grand_total}")
