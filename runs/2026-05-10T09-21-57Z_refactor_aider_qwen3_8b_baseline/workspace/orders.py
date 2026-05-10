orders = [
    {
        'customer': 'alice',
        'orders': [
            {'item': 'apple', 'quantity': 2, 'price': 1.5},
            {'item': 'banana', 'quantity': 3, 'price': 2.5},
            {'item': 'orange', 'quantity': 1, 'price': 3.0},
        ]
    },
    {
        'customer': 'bob',
        'orders': [
            {'item': 'apple', 'quantity': 4, 'price': 1.5},
            {'item': 'banana', 'quantity': 5, 'price': 2.5},
            {'item': 'orange', 'quantity': 2, 'price': 3.0},
        ]
    },
    {
        'customer': 'carol',
        'orders': [
            {'item': 'apple', 'quantity': 1, 'price': 1.5},
            {'item': 'banana', 'quantity': 1, 'price': 2.5},
        ]
    }
]

def customer_total(order):
    total = 0.0
    for item in order['orders']:
        total += item['quantity'] * item['price']
    return total

customer_totals = []
for order in orders:
    total = customer_total(order)
    customer_totals.append(total)
    print(f"{order['customer'].title()} paid {total:.1f}")

grand_total = sum(customer_totals)
print(f"grand total {grand_total:.1f}")
