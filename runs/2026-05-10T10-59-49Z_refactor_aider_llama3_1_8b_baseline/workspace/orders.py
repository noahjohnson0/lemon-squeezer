import math

def customer_total(order):
    # Calculate the total for one order
    subtotal = sum(item['price'] * item['quantity'] for item in order['items'])
    tax_rate = 0.08  # 8% sales tax
    discount = 0.05 if 'discount' in order else 0
    return math.ceil(subtotal * (1 + tax_rate) * (1 - discount), 2)

def print_order(order):
    name = order['name']
    total = customer_total(order)
    print(f"{name} paid {total}")

orders = [
    {'name': 'alice', 'items': [{'price': 5.0, 'quantity': 1}, {'price': 3.5, 'quantity': 2}], 'discount': True},
    {'name': 'bob', 'items': [{'price': 10.0, 'quantity': 2}, {'price': 11.0, 'quantity': 1}]},
    {'name': 'carol', 'items': [{'price': 1.5, 'quantity': 3}]}
]

for order in orders:
    print_order(order)

grand_total = sum(customer_total(o) for o in orders)
print(f"grand total {grand_total}")
