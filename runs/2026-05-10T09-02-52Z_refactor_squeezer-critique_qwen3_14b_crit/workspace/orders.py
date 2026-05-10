"""Calculate order totals. Has a bug AND lots of duplication.""

orders = [
    {"customer": "alice", "items": [("apple", 3, 1.50), ("bread", 1, 4.00)]},
    {"customer": "bob",   "items": [("apple", 5, 1.50), ("eggs", 2, 3.00), ("bread", 2, 4.00)]},
    {"customer": "carol", "items": [("eggs", 1, 3.00)]},
]


def customer_total(order):
    total = 0
    for item, qty, price in order["items"]:
        total += qty * price
    return total


totals = []
for order in orders:
    customer = order["customer"]
    total = customer_total(order)
    totals.append(total)
    print(f"{customer} paid {total}")

grand_total = sum(totals)
print(f"grand total {grand_total}")