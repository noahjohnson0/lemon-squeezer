"""Calculate order totals. Has a bug AND lots of duplication."""

orders = [
    {"customer": "alice", "items": [("apple", 3, 1.50), ("bread", 1, 4.00)]},
    {"customer": "bob",   "items": [("apple", 5, 1.50), ("eggs", 2, 3.00), ("bread", 2, 4.00)]},
    {"customer": "carol", "items": [("eggs", 1, 3.00)]},
]

def calculate_total(order):
    total = 0
    for item, qty, price in order["items"]:
        total = total + qty * price
    return total

# Total for each customer
totals = []
for order in orders:
    customer_total = calculate_total(order)
    print(f"{order['customer']} paid", customer_total)
    totals.append(customer_total)

# Grand total
grand = sum(totals)
print("grand total", grand)