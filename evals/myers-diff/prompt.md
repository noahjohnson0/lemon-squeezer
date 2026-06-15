Write `mydiff.py` exporting a minimal line-diff, implemented from scratch
(stdlib only - **no `difflib`, no third-party libraries**):

```python
def diff(a_lines: list[str], b_lines: list[str]) -> list[tuple[str, str]]:
    """Compute a MINIMAL line-level edit script transforming a_lines into
    b_lines.

    Return a list of (tag, line) tuples in order, where tag is one of:
        '='  the line is unchanged (present in both a and b),
        '-'  the line is deleted (present in a, not in this position of b),
        '+'  the line is inserted (present in b, not in a).

    Requirements:
      * The script must be MINIMAL: the total number of '-' and '+' tuples
        must equal len(a) + len(b) - 2*LCS(a, b), where LCS is the length of
        the longest common subsequence of the two line lists. Equivalently,
        the number of '=' tuples must equal LCS(a, b). A diff that merely
        replaces a changed region wholesale (delete-all-then-insert-all) is
        NOT minimal and will fail.
      * The '=' lines, read in order, must equal the longest common
        subsequence of a_lines and b_lines.
      * Reading every tuple that is '=' or '-' (in order) reproduces a_lines.
      * Reading every tuple that is '=' or '+' (in order) reproduces b_lines.
      * Must run on inputs of ~2000 lines well within a few seconds (an
        exponential / unmemoized-recursive algorithm will time out). Use an
        O(n*m) (or better) dynamic-programming / Myers algorithm.
    """

def apply(a_lines: list[str], script: list[tuple[str, str]]) -> list[str]:
    """Apply an edit script (as returned by diff) to a_lines and return the
    resulting list of lines. For every tuple:
        '=' -> consume one line from a and emit it,
        '-' -> consume one line from a and emit nothing,
        '+' -> emit the tuple's line without consuming from a.
    apply(a, diff(a, b)) must equal b for all a, b."""
```

## Edge cases the grader exercises (handle ALL of them)

* Empty inputs: `diff([], [])`, `diff([], b)` (all inserts), `diff(a, [])`
  (all deletes).
* Identical inputs: every tuple is `'='`, zero `-`/`+`.
* Interleaved edits where a naive "common-prefix / common-suffix then replace
  the middle" diff is non-minimal (e.g. changing every other line, or a small
  edit buried between two large unchanged blocks that also share lines).
* Duplicate lines: when the same line text appears many times the LCS must
  still be maximised (e.g. `["a","b","a","b","a"]` vs `["b","a","b","a","b"]`).
* Transposition / reordering of blocks.
* A single line changed in a large file (most lines must stay `'='`).
* The minimal edit count must match `len(a)+len(b)-2*LCS` exactly on adversarial
  cases - off-by-one or greedy diffs will be caught.
* Round-trip: `apply(a, diff(a, b)) == b` on every case, including the empties.
* Performance: a ~2000 vs ~2000 line input (with a long common subsequence)
  must complete quickly under the grader's timeout.

Create only `mydiff.py`. Do not run it. Stdlib only.
