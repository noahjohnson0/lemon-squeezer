def solve(items: list[tuple[int, int]], capacity: int) -> tuple[int, list[int]]:
    """0/1 knapsack via dynamic programming.

    items: list of (weight, value) tuples.
    capacity: integer maximum total weight.

    Returns (max_value, indices) where `indices` is a list of item indices
    (any order) whose total weight ≤ capacity and total value == max_value.
    For ties (multiple optimal solutions), return any valid one."""
    n = len(items)
    if n == 0 or capacity == 0:
        return (0, [])
    
    # Initialize DP table
    dp = [[0] * (capacity + 1) for _ in range(n + 1)]
    
    for i in range(1, n + 1):
        weight, value = items[i - 1]
        for w in range(capacity + 1):
            if weight <= w:
                dp[i][w] = max(dp[i - 1][w], dp[i - 1][w - weight] + value)
            else:
                dp[i][w] = dp[i - 1][w]
    
    # Backtrack to find selected items
    selected = []
    current_weight = capacity
    current_value = dp[n][capacity]
    
    for i in range(n, 0, -1):
        if current_value > dp[i - 1][current_weight]:
            selected.append(i - 1)
            current_value -= items[i - 1][1]
            current_weight -= items[i - 1][0]
    
    return (dp[n][capacity], selected)
