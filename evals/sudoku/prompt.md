Write `sudoku.py` exporting one function:

```python
def solve(board: list[list[int]]) -> list[list[int]]:
    """
    Solve a 9x9 Sudoku. The input is a 9x9 list-of-lists where 0 represents an empty cell
    and digits 1..9 are given clues. Return a 9x9 list-of-lists with all cells filled in,
    obeying the Sudoku constraints (each row, column, and 3x3 box contains 1..9 exactly once).
    Raise ValueError if no solution exists.
    """
```

Implementation notes:
- A constraint-propagation + backtracking solver is plenty fast for 9x9.
- Do NOT mutate the input — return a new board.
- Must handle hard puzzles (i.e. ones where naive constraint propagation alone won't fill all cells).

Create only `sudoku.py`. Don't run it.
