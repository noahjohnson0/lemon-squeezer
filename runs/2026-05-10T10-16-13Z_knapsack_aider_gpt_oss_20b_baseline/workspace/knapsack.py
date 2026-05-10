"""
knapsack.py

Provides a 0/1 knapsack solver using bottom‑up dynamic programming.

The public API is a single function:

    solve(items: list[tuple[int, int]], capacity: int) -> tuple[int, list[int]]

where `items` is a list of (weight, value) tuples and `capacity` is the
maximum total weight allowed.  The function returns a tuple containing
the maximum achievable value and a list of indices of items that
constitute that value.  Any optimal solution may be returned in case of
ties.
"""

from __future__ import annotations
from typing import List, Tuple


def solve(items: List[Tuple[int, int]], capacity: int) -> Tuple[int, List[int]]:
    """
    0/1 knapsack via dynamic programming.

    items: list of (weight, value) tuples.
    capacity: integer maximum total weight.

    Returns (max_value, indices) where `indices` is a list of item indices
    (any order) whose total weight ≤ capacity and total value == max_value.
    For ties (multiple optimal solutions), return any valid one.
    """
    n = len(items)

    # Edge cases: no items or zero capacity
    if n == 0 or capacity <= 0:
        return 0, []

    # dp[i][c] will hold the maximum value achievable using the first i items
    # with a capacity limit of c.  We use a 2‑D list for clarity.
    dp = [[0] * (capacity + 1) for _ in range(n + 1)]

    # Build the DP table
    for i in range(1, n + 1):
        w, v = items[i - 1]
        for c in range(capacity + 1):
            if w <= c:
                # Option 1: skip the item
                skip = dp[i - 1][c]
                # Option 2: take the item (if it fits)
                take = dp[i - 1][c - w] + v
                dp[i][c] = max(skip, take)
            else:
                # Item too heavy to fit in this capacity
                dp[i][c] = dp[i - 1][c]

    max_value = dp[n][capacity]

    # Backtrack to find which items were taken
    indices: List[int] = []
    c = capacity
    for i in range(n, 0, -1):
        if dp[i][c] != dp[i - 1][c]:
            # Item i-1 was taken
            indices.append(i - 1)
            c -= items[i - 1][0]  # subtract its weight

    return max_value, indices
