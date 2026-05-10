"""knapsack.py

Provides a classic 0/1 knapsack solver using dynamic programming.

The public interface is a single function `solve` that accepts a list of
( weight, value ) tuples and a maximum capacity.  It returns a tuple of
( maximum value, list of indices ).  The list contains the indices of the
items selected to achieve that value; the order of indices is arbitrary.
"""

from __future__ import annotations

from typing import List, Tuple


+def solve(items: List[Tuple[int, int]], capacity: int) -> Tuple[int, List[int]]:
+    """Return the maximum value achievable with at most ``capacity`` weight.
+
+    Parameters
+    ----------
+    items:
+        A list of ``(weight, value)`` tuples.  Items are 0‑indexed for
+        return; the order is the order in which they are supplied.
+    capacity:
+        The maximal total weight that may be selected.
+
+    Returns
+    -------
+    tuple[int, list[int]]
+        ``(max_value, indices)`` where ``max_value`` is the best total
+        value reachable and ``indices`` is a list of item indices whose
+        total weight does not exceed ``capacity``.
+    """
+
+    n = len(items)
+    # Edge cases
+    if n == 0 or capacity <= 0:
+        return 0, []
+
+    # DP table: dp[i][w] = best value using first i items with capacity w.
+    dp = [[0] * (capacity + 1) for _ in range(n + 1)]
+
+    for i in range(1, n + 1):
+        weight, value = items[i - 1]
+        for w in range(capacity + 1):
+            if w < weight:
+                dp[i][w] = dp[i - 1][w]
+            else:
+                without = dp[i - 1][w]
+                with_item = dp[i - 1][w - weight] + value
+                dp[i][w] = without if without >= with_item else with_item
+
+    max_value = dp[n][capacity]
+    indices: List[int] = []
+    i, w = n, capacity
+    while i > 0 and w >= 0:
+        if dp[i][w] != dp[i - 1][w]:
+            # Item i-1 was taken
+            indices.append(i - 1)
+            w -= items[i - 1][0]
+        i -= 1
+
+    return max_value, indices
+
*** End of File
