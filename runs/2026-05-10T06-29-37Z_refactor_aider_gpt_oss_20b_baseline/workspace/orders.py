orders = [
    {
        'customer': 'alice',
        'items': [
            {'price': 2.5},
            {'price': 6.0}
        ]
    },
    {
        'customer': 'bob',
        'items': [
            {'price': 10.0},
            {'price': 11.5}
        ]
    },
    {
        'customer': 'carol',
        'items': [
            {'price': 3.0}
        ]
    }
]

def customer_total(order):
    """Calculate the total price for a single order."""
    return sum(item.get('price', 0) for item in order.get('items', []))

def main():
    grand_total = 0.0
    for order in orders:
        total = customer_total(order)
        print(f"{order['customer']} paid {total}")
        grand_total += total
    print(f"grand total {grand_total}")

if __name__ == "__main__":
    main()
