from typing import List, Tuple

def solve(items: List[Tuple[int, int]], capacity: int) -> Tuple[int, List[int]]:
    """0/1 knapsack via dynamic programming.

    items: list of (weight, value) tuples.
    capacity: integer maximum total weight.

    Returns (max_value, indices) where `indices` is a list of item indices
    (any order) whose total weight ≤ capacity and total value == max_value.
    For ties (multiple optimal solutions), return any valid one."""
    n = len(items)
    # Initialize DP table
    dp = [[0]*(capacity+1) for _ in range(n+1)]
    
    # Fill DP table
    for i in range(1, n+1):
        weight, value = items[i-1]
        for w in range(capacity+1):
            if weight > w:
                dp[i][w] = dp[i-1][w]
            else:
                dp[i][w] = max(dp[i-1][w], dp[i-1][w - weight] + value)
    
    # Backtrack to find selected items
    selected_indices = []
    current_value = dp[n][capacity]
    current_weight = capacity
    current_item = n
    
    while current_item > 0 and current_weight > 0:
        if dp[current_item][current_weight] != dp[current_item-1][current_weight]:
            # Item is included
            selected_indices.append(current_item - 1)
            current_weight -= items[current_item - 1][0]
            current_item -= 1
        else:
            current_item -= 1
    
    return (current_value, selected_indices)
