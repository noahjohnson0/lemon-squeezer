def solve(items: list[tuple[int, int]], capacity: int) -> tuple[int, list[int]]:
    """0/1 knapsack via dynamic programming.

    items: list of (weight, value) tuples.
    capacity: integer maximum total weight.

    Returns (max_value, indices) where `indices` is a list of item indices
    (any order) whose total weight ≤ capacity and total value == max_value.
    For ties (multiple optimal solutions), return any valid one."""
    n = len(items)
    # Initialize DP table with (n+1) rows and (capacity+1) columns
    dp = [[0] * (capacity + 1) for _ in range(n + 1)]

    # Fill the DP table
    for i in range(1, n + 1):
        weight, value = items[i - 1]
        for w in range(1, capacity + 1):
            if weight > w:
                dp[i][w] = dp[i - 1][w]
            else:
                dp[i][w] = max(dp[i - 1][w], dp[i - 1][w - weight] + value)

    # Backtrack to find the selected items
    selected_indices = []
    i, w = n, capacity
    while i > 0 and w > 0:
        if dp[i][w] != dp[i - 1][w]:
            selected_indices.append(i - 1)
            weight_i, _ = items[i - 1]
            w -= weight_i
            i -= 1
        else:
            i -= 1

    return (dp[n][capacity], selected_indices)
