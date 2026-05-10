"""Calculate order totals. Refactored to avoid duplication.
"""

orders = [
    {"customer": "alice", "items": [("apple", 3, 1.50), ("bread", 1, 4.00)]},
    {"customer": "bob",   "items": [("apple", 5, 1.50), ("eggs", 2, 3.00), ("bread", 2, 4.00)]},
    {"customer": "carol", "items": [("eggs", 1, 3.00)]},
]


def customer_total(order):
    """Return the total amount for a single order.

    Parameters
    ----------
    order : dict
        Order dictionary with an ``items`` list of tuples
        ``(name, quantity, unit_price)``.

    Returns
    -------
    float
        Total cost for this customer.
    """
    total = 0.0
    for item, qty, price in order["items"]:
        total += qty * price
    return total

# Print per-customer totals and keep track of grand total
grand_total = 0.0
for order in orders:
    total = customer_total(order)
    print(f"{order['customer']} paid", total)
    grand_total += total

print("grand total", grand_total)
