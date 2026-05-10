def solve(items: list[tuple[int, int]], capacity: int) -> tuple[int, list[int]]:
    """0/1 knapsack via dynamic programming.

    items: list of (weight, value) tuples.
    capacity: integer maximum total weight.

    Returns (max_value, indices) where `indices` is a list of item indices
    (any order) whose total weight ≤ capacity and total value == max_value.
    For ties (multiple optimal solutions), return any valid one."""
    
    n = len(items)
    # Create a 2D DP table
    dp = [[0 for _ in range(capacity + 1)] for _ in range(n + 1)]
    
    # Fill the DP table
    for i in range(1, n + 1):
        weight, value = items[i - 1]
        for w in range(capacity + 1):
            # Don't take the item
            dp[i][w] = dp[i - 1][w]
            # Take the item if it fits
            if weight <= w:
                dp[i][w] = max(dp[i][w], dp[i - 1][w - weight] + value)
    
    # Backtrack to find the items included in the optimal solution
    max_value = dp[n][capacity]
    indices = []
    w = capacity
    for i in range(n, 0, -1):
        # If value is different from the value above, item was included
        if dp[i][w] != dp[i - 1][w]:
            indices.append(i - 1)  # 0-indexed
            w -= items[i - 1][0]   # Reduce capacity by item's weight
    
    return (max_value, indices)
