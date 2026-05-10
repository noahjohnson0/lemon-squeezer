Write `sat.py` exporting a SAT solver for CNF (conjunctive normal form):

```python
def solve(clauses: list[list[int]]) -> dict[int, bool] | None:
    """Solve a CNF SAT problem.

    `clauses` is a list of clauses; each clause is a list of integers where
    a positive integer N means variable N must be True and a negative integer -N
    means variable N must be False (literal). All clauses must be satisfied (AND).
    Each clause is satisfied if at least one literal is True (OR within clause).

    Returns:
      - {var_id: True/False, ...} satisfying assignment for ALL variables present, OR
      - None if the formula is UNSAT.

    Variables not constrained by any clause MAY appear in the result with any value
    (or be omitted)."""
```

Implement DPLL or any complete algorithm. Pure stdlib. Don't import `python-sat` or `pycosat`.

Create only `sat.py`. Don't run it.
