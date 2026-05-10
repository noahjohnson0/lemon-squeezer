"""
Levenshtein distance and edit path implementation.

This module provides two functions:

* `edit_distance(a: str, b: str) -> int`
  Computes the standard Levenshtein edit distance between two strings.

* `edit_path(a: str, b: str) -> list[tuple[str, str, str]]`
  Returns a list of edit operations that transform `a` into `b`. Each
  operation is a tuple `(op, src_char, dst_char)` where `op` is one of
  `'match'`, `'sub'`, `'ins'`, or `'del'`.

The implementation uses dynamic programming and only relies on the
Python standard library.
"""

from __future__ import annotations
from typing import List, Tuple


def edit_distance(a: str, b: str) -> int:
    """
    Standard Levenshtein edit distance: minimum number of single-character
    insertions, deletions, or substitutions to transform `a` into `b`.

    Parameters
    ----------
    a : str
        Source string.
    b : str
        Target string.

    Returns
    -------
    int
        The edit distance between `a` and `b`.
    """
    m, n = len(a), len(b)
    # Create a (m+1) x (n+1) matrix
    dp: List[List[int]] = [[0] * (n + 1) for _ in range(m + 1)]

    # Initialize first row and column
    for i in range(m + 1):
        dp[i][0] = i  # delete all i characters
    for j in range(n + 1):
        dp[0][j] = j  # insert all j characters

    # Fill the matrix
    for i in range(1, m + 1):
        for j in range(1, n + 1):
            cost = 0 if a[i - 1] == b[j - 1] else 1
            dp[i][j] = min(
                dp[i - 1][j] + 1,      # deletion
                dp[i][j - 1] + 1,      # insertion
                dp[i - 1][j - 1] + cost,  # substitution or match
            )

    return dp[m][n]


def edit_path(a: str, b: str) -> List[Tuple[str, str, str]]:
    """
    Return the list of operations as (op, src_char, dst_char) tuples where
    `op` is one of 'match', 'sub', 'ins', 'del'. The number of non-'match'
    ops must equal `edit_distance(a, b)`. For 'match'/'sub', `src_char` and
    `dst_char` are the corresponding characters from `a` and `b`. For
    'ins', `src_char` is '' and `dst_char` is the inserted character. For
    'del', `dst_char` is ''.

    Parameters
    ----------
    a : str
        Source string.
    b : str
        Target string.

    Returns
    -------
    List[Tuple[str, str, str]]
        Ordered list of edit operations transforming `a` into `b`.
    """
    m, n = len(a), len(b)
    # Build DP matrix as in edit_distance
    dp: List[List[int]] = [[0] * (n + 1) for _ in range(m + 1)]
    for i in range(m + 1):
        dp[i][0] = i
    for j in range(n + 1):
        dp[0][j] = j
    for i in range(1, m + 1):
        for j in range(1, n + 1):
            cost = 0 if a[i - 1] == b[j - 1] else 1
            dp[i][j] = min(
                dp[i - 1][j] + 1,
                dp[i][j - 1] + 1,
                dp[i - 1][j - 1] + cost,
            )

    # Backtrack to build the path
    ops: List[Tuple[str, str, str]] = []
    i, j = m, n
    while i > 0 or j > 0:
        # If both indices are > 0, we can consider diagonal move
        if i > 0 and j > 0:
            cost = 0 if a[i - 1] == b[j - 1] else 1
            if dp[i][j] == dp[i - 1][j - 1] + cost:
                if cost == 0:
                    ops.append(("match", a[i - 1], b[j - 1]))
                else:
                    ops.append(("sub", a[i - 1], b[j - 1]))
                i -= 1
                j -= 1
                continue

        # If deletion is the best move
        if i > 0 and dp[i][j] == dp[i - 1][j] + 1:
            ops.append(("del", a[i - 1], ""))
            i -= 1
            continue

        # If insertion is the best move
        if j > 0 and dp[i][j] == dp[i][j - 1] + 1:
            ops.append(("ins", "", b[j - 1]))
            j -= 1
            continue

        # Fallback (should not happen if DP is correct)
        raise RuntimeError("Failed to reconstruct edit path")

    ops.reverse()
    return ops
