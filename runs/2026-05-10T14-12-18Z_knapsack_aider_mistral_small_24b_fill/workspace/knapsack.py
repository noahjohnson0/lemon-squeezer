def solve(items: list[tuple[int, int]], capacity: int) -> tuple[int, list[int]]:
    """0/1 knapsack via dynamic programming.

    items: list of (weight, value) tuples.
    capacity: integer maximum total weight.

    Returns (max_value, indices) where `indices` is a list of item indices
    (any order) whose total weight ≤ capacity and total value == max_value.
    For ties (multiple optimal solutions), return any valid one."""

    n = len(items)
    # Create a 2D DP table to store the maximum value at each subproblem
    dp = [[0 for _ in range(capacity + 1)] for _ in range(n + 1)]

    # Fill the DP table
    for i in range(1, n + 1):
        weight, value = items[i - 1]
        for w in range(capacity + 1):
            if weight <= w:
                dp[i][w] = max(dp[i - 1][w], dp[i - 1][w - weight] + value)
            else:
                dp[i][w] = dp[i - 1][w]

    # Reconstruct the solution
    max_value = dp[n][capacity]
    w = capacity
    selected_indices = []
    for i in range(n, 0, -1):
        if dp[i][w] != dp[i - 1][w]:
            weight, _ = items[i - 1]
            selected_indices.append(i - 1)
            w -= weight

    return max_value, selected_indices
