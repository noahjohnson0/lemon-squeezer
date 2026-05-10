"""Calculate order totals. Has a bug AND lots of duplication."""

orders = [
    {"customer": "alice", "items": [("apple", 3, 1.50), ("bread", 1, 4.00)]},
    {"customer": "bob",   "items": [("apple", 5, 1.50), ("eggs", 2, 3.00), ("bread", 2, 4.00)]},
    {"customer": "carol", "items": [("eggs", 1, 3.00)]},
]

# Total for alice
alice_total = 0
for item, qty, price in orders[0]["items"]:
    alice_total = alice_total + qty * price
print("alice paid", alice_total)

# Total for bob
bob_total = 0
for item, qty, price in orders[1]["items"]:
    bob_total = bob_total + qty * price
print("bob paid", bob_total)

# Total for carol
carol_total = 0
for item, qty, price in orders[2]["items"]:
    carol_total = carol_total + qty * price
print("carol paid", carol_total)

# Grand total
grand = alice_total + bob_total + carol_total
print("grand total", grand)
