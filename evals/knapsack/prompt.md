Write `knapsack.py` exporting:

```python
def solve(items: list[tuple[int, int]], capacity: int) -> tuple[int, list[int]]:
    """0/1 knapsack via dynamic programming.

    items: list of (weight, value) tuples.
    capacity: integer maximum total weight.

    Returns (max_value, indices) where `indices` is a list of item indices
    (any order) whose total weight ≤ capacity and total value == max_value.
    For ties (multiple optimal solutions), return any valid one."""
```

Use bottom-up DP with a 2D table. No third-party libs.

Create only `knapsack.py`. Don't run it.
