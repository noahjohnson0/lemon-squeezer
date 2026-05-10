"""Implementation of standard Levenshtein edit distance and path.

The module exposes two functions:

* ``edit_distance(a, b)`` – returns the minimal number of single‑character
  edit operations required to transform ``a`` into ``b``.
* ``edit_path(a, b)`` – returns a list of operations that achieves that
  minimal edit distance. Each operation is represented as a tuple
  ``(op, src_char, dst_char)`` where ``op`` is one of ``'match'``, ``'sub'``,
  ``'ins'`` or ``'del'``.

The implementation uses dynamic programming and runs in ``O(len(a) * len(b)``
time and memory). No external dependencies are required.
"""

from __future__ import annotations

__all__ = ["edit_distance", "edit_path"]


def _levenshtein_matrix(a: str, b: str):
    """Return a 2‑D list ``dp`` where ``dp[i][j]`` is the edit distance between
    ``a[:i]`` and ``b[:j]``.
    """
    m, n = len(a), len(b)
    dp = [[0] * (n + 1) for _ in range(m + 1)]
    # Base cases
    for i in range(1, m + 1):
        dp[i][0] = i
    for j in range(1, n + 1):
        dp[0][j] = j
    # Fill table
    for i in range(1, m + 1):
        ai = a[i - 1]
        for j in range(1, n + 1):
            bj = b[j - 1]
            cost = 0 if ai == bj else 1
            dp[i][j] = min(
                dp[i - 1][j] + 1,      # delete ai
                dp[i][j - 1] + 1,      # insert bj
                dp[i - 1][j - 1] + cost,  # replace or match
            )
    return dp


def edit_distance(a: str, b: str) -> int:
    """Return the Levenshtein edit distance between ``a`` and ``b``.

    The distance is the minimal number of single‑character insertions,
    deletions, or substitutions required to convert ``a`` into ``b``.
    """
    dp = _levenshtein_matrix(a, b)
    return dp[-1][-1]


def edit_path(a: str, b: str) -> list[tuple[str, str, str]]:
    """Return the sequence of edit operations that transform ``a`` into ``b``.

    Each operation is a 3‑tuple ``(op, src_char, dst_char)`` where ``op`` is
    one of ``'match'``, ``'sub'``, ``'ins'`` or ``'del'``.

    ``edit_path`` guarantees that the number of non‑``'match'`` operations
    equals ``edit_distance(a, b)``.
    """
    dp = _levenshtein_matrix(a, b)
    ops: list[tuple[str, str, str]] = []
    i, j = len(a), len(b)
    while i > 0 or j > 0:
        # When both indices are > 0, check if a match or substitution is optimal.
        if i > 0 and j > 0:
            ai = a[i - 1]
            bj = b[j - 1]
            cost = 0 if ai == bj else 1
            if dp[i][j] == dp[i - 1][j - 1] + cost:
                op = "match" if cost == 0 else "sub"
                ops.append((op, ai, bj))
                i -= 1
                j -= 1
                continue
        # If deletion is the optimal step.
        if i > 0 and dp[i][j] == dp[i - 1][j] + 1:
            ops.append(("del", a[i - 1], ""))
            i -= 1
        else:
            # Insertion must be optimal.
            ops.append(("ins", "", b[j - 1]))
            j -= 1
    return list(reversed(ops))

# Simple self‑check when run as a script.
if __name__ == "__main__":
    import sys
    if len(sys.argv) == 3:
        a, b = sys.argv[1], sys.argv[2]
        print("distance:", edit_distance(a, b))
        print("path:")
        for op in edit_path(a, b):
            print(op)
    else:
        print("Usage: python levenshtein.py <str_a> <str_b>")
        sys.exit(1)
