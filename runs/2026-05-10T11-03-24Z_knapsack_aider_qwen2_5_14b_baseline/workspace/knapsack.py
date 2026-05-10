from typing import List, Tuple

def solve(items: List[Tuple[int, int]], capacity: int) -> Tuple[int, List[int]]:
    """0/1 knapsack via dynamic programming.

    items: list of (weight, value) tuples.
    capacity: integer maximum total weight.

    Returns (max_value, indices) where `indices` is a list of item indices
    (any order) whose total weight ≤ capacity and total value == max_value.
    For ties (multiple optimal solutions), return any valid one."""
    
    n = len(items)
    dp_table = [[0] * (capacity + 1) for _ in range(n + 1)]
    
    # Fill DP table
    for i in range(1, n + 1):
        weight, value = items[i - 1]
        for w in range(capacity + 1):
            if weight <= w:
                dp_table[i][w] = max(dp_table[i-1][w], dp_table[i-1][w-weight] + value)
            else:
                dp_table[i][w] = dp_table[i-1][w]
    
    # Traceback to find the items
    solution_indices = []
    w = capacity
    for i in range(n, 0, -1):
        if dp_table[i][w] != dp_table[i-1][w]:
            solution_indices.append(i-1)
            w -= items[i-1][0]
    
    return (dp_table[n][capacity], solution_indices[::-1])
