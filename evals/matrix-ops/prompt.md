Write `matops.py` exporting linear-algebra primitives, IMPLEMENTED MANUALLY (no numpy.linalg, no scipy):

```python
def determinant(M: list[list[float]]) -> float:
    """Determinant of an n×n matrix via LU decomposition or expansion-by-minors.
    Raise ValueError if not square."""

def inverse(M: list[list[float]]) -> list[list[float]]:
    """Invert an n×n matrix via Gauss-Jordan elimination.
    Raise ValueError if singular (|det| < 1e-10) or not square."""

def matmul(A: list[list[float]], B: list[list[float]]) -> list[list[float]]:
    """Matrix product. Raise ValueError on shape mismatch."""
```

You MAY use `numpy` for array storage and elementary arithmetic, but you MAY NOT call `numpy.linalg.det`, `numpy.linalg.inv`, `numpy.linalg.solve` etc. Implement the elimination yourself.

Create only `matops.py`. Don't run it.
