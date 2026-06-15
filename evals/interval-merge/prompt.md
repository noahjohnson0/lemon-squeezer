Write `intervals.py` exporting three functions that operate on closed integer
intervals. An interval is a 2-element pair `[start, end]` with `start <= end`.
A list of intervals is a Python `list` of such pairs.

```python
def merge(intervals: list[list[int]]) -> list[list[int]]:
    """Return a NEW list of disjoint intervals covering exactly the same points
    as the input, sorted ascending by start.

    - Overlapping intervals are merged.
    - TOUCHING / ADJACENT intervals merge too: [1,3] and [3,5] -> [1,5]
      (they share the endpoint 3), and [1,2] and [3,4] also merge because
      these are INTEGER intervals and 2 and 3 are adjacent integers ->
      [1,4]. Two integer intervals merge iff b.start <= a.end + 1.
    - Containment collapses: [1,10] and [3,4] -> [1,10].
    - Input may be unsorted and may contain duplicates.
    - The empty list returns [].
    - Do NOT mutate the input list or its inner pairs; return fresh lists.
    """

def insert(intervals: list[list[int]], new: list[int]) -> list[list[int]]:
    """Insert `new` into an ALREADY-SORTED, ALREADY-DISJOINT list `intervals`
    and return a NEW sorted, disjoint list. Merge `new` with any intervals it
    overlaps with or is adjacent to (same integer-adjacency rule as merge).
    Inserting into [] yields [new]. Must run in O(n): a single pass, NOT
    merge(intervals + [new]). Do not mutate inputs.
    """

def intersect(a: list[list[int]], b: list[list[int]]) -> list[list[int]]:
    """Given two SORTED, DISJOINT lists `a` and `b`, return the SORTED, DISJOINT
    list of their pairwise intersections (the points covered by BOTH).

    - Touching at a single integer counts: [1,3] ∩ [3,5] = [[3,3]].
    - Non-overlapping inputs return [].
    - Either input empty returns [].
    - Must run in O(len(a) + len(b)) via a two-pointer sweep. Do not mutate
      inputs.
    """
```

## Validation

- `merge` and `insert` must raise `ValueError` if any interval has
  `start > end`. `intersect` may assume well-formed inputs.

## Performance (this is graded)

`merge` must handle 100,000 intervals comfortably. A correct `O(n log n)`
solution (sort, then a single linear sweep) finishes in well under a second.
An `O(n^2)` approach (e.g. repeatedly scanning the whole accumulated result
for something to merge, or pairwise re-merging in a loop) will be too slow and
will FAIL the performance check. Likewise `insert` and `intersect` are checked
for linear-time behavior on large inputs.

## Constraints

- Pure Python standard library only. No third-party packages.
- Create only `intervals.py`. Do not print anything; do not run it.
