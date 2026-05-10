"""
MatOps – basic linear algebra primitives implemented manually.

This module provides a few core operations such as determinant,
inverse and matrix multiplication.  All functions operate on basic
Python ``list[list[float]]`` types – no external linear algebra
libraries are used for the core computations.

The implementation favours clarity over performance and is meant
for educational and demonstration purposes.  It is not intended to
replace production‑grade libraries such as ``numpy.linalg``.
"""

from __future__ import annotations

__all__ = ["determinant", "inverse", "matmul"]


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _is_square(M: list[list[float]]) -> bool:
    """Return ``True`` iff *M* is a non‑empty square matrix.

    The function checks that each row has the same length and that the
    number of rows equals the number of columns.
    """
    if not M:
        return False
    n = len(M)
    return all(len(row) == n for row in M)


# ---------------------------------------------------------------------------
# Determinant
# ---------------------------------------------------------------------------

def determinant(M: list[list[float]]) -> float:
    """Return the determinant of a square matrix *M*.

    The algorithm performs Gaussian elimination with partial
    pivoting.  While pivoting is primarily for numerical stability
    it also keeps the implementation simple.  The determinant is
    calculated as the product of the diagonal entries of the
    resulting upper‑triangular matrix, multiplied by ``-1`` for each
    row swap.

    Parameters
    ----------
    M:
        A square matrix represented as a list of rows.

    Raises
    ------
    ValueError
        If *M* is not square.
    """
    if not _is_square(M):
        raise ValueError("determinant requires a square matrix")

    n = len(M)
    # Work on a copy to avoid mutating the input.
    A = [row[:] for row in M]
    det_sign = 1.0

    for i in range(n):
        # Partial pivot: find the row with the largest absolute value in column i
        pivot_row = max(range(i, n), key=lambda r: abs(A[r][i]))
        if abs(A[pivot_row][i]) < 1e-12:
            # Pivot is effectively zero → singular matrix
            return 0.0
        if pivot_row != i:
            # Swap rows and toggle sign
            A[i], A[pivot_row] = A[pivot_row], A[i]
            det_sign *= -1.0

        pivot = A[i][i]
        for j in range(i + 1, n):
            factor = A[j][i] / pivot
            # Eliminate entry A[j][i]
            for k in range(i, n):
                A[j][k] -= factor * A[i][k]

    det = det_sign
    for i in range(n):
        det *= A[i][i]
    return det


# ---------------------------------------------------------------------------
# Inverse – Gauss‑Jordan elimination
# ---------------------------------------------------------------------------

def inverse(M: list[list[float]]) -> list[list[float]]:
    """Return the inverse of a square matrix *M*.

    The algorithm performs Gauss‑Jordan elimination on the augmented
    matrix ``[M | I]`` where ``I`` is the identity matrix.

    Parameters
    ----------
    M:
        A square, nonsingular matrix.

    Returns
    -------
    list[list[float]]
        The inverse matrix.

    Raises
    ------
    ValueError
        If *M* is not square or if it is singular (|det| < 1e‑10).
    """
    if not _is_square(M):
        raise ValueError("inverse requires a square matrix")

    n = len(M)
    # Check singularity early via determinant
    if abs(determinant(M)) < 1e-10:
        raise ValueError("matrix is singular or ill‑conditioned")

    # Build augmented matrix [M | I]
    Aug = [row[:] + [float(i == j) for j in range(n)] for i, row in enumerate(M)]

    for i in range(n):
        # Partial pivoting for numerical stability
        pivot_row = max(range(i, n), key=lambda r: abs(Aug[r][i]))
        if abs(Aug[pivot_row][i]) < 1e-12:
            raise ValueError("matrix is singular during elimination")
        if pivot_row != i:
            Aug[i], Aug[pivot_row] = Aug[pivot_row], Aug[i]

        pivot = Aug[i][i]
        # Normalize pivot row
        for k in range(2 * n):
            Aug[i][k] /= pivot

        # Eliminate other rows
        for r in range(n):
            if r == i:
                continue
            factor = Aug[r][i]
            for k in range(2 * n):
                Aug[r][k] -= factor * Aug[i][k]

    # Extract the right block as the inverse
    inv = [row[n:] for row in Aug]
    return inv


# ---------------------------------------------------------------------------
# Matrix multiplication
# ---------------------------------------------------------------------------

def matmul(A: list[list[float]], B: list[list[float]]) -> list[list[float]]:
    """Return the product of matrices *A* and *B*.

    Parameters
    ----------
    A, B:
        Matrices in row‑major order.

    Returns
    -------
    list[list[float]]
        The matrix product ``A × B``.

    Raises
    ------
    ValueError
        If the number of columns in *A* doesn't match the number of rows in *B*.
    """
    if not A or not B:
        raise ValueError("matmul requires non‑empty matrices")
    if len(A[0]) != len(B):
        raise ValueError("shape mismatch: cannot multiply matrices")

    m = len(A)
    k = len(A[0])
    n = len(B[0])
    # Initialize result matrix with zeros
    result: list[list[float]] = [[0.0] * n for _ in range(m)]

    for i in range(m):
        for j in range(n):
            s = 0.0
            for l in range(k):
                s += A[i][l] * B[l][j]
            result[i][j] = s
    return result


# ---------------------------------------------------------------------------
# Simple self‑test when run as script
# ---------------------------------------------------------------------------
if __name__ == "__main__":
    import math

    A = [[1, 2], [3, 4]]
    B = [[5, 6], [7, 8]]
    print("A =", A)
    print("B =", B)
    print("A×B =", matmul(A, B))
    print("det(A) =", determinant(A))
    print("inv(A) =", inverse(A))
    print("A × inv(A) =", matmul(A, inverse(A)))
    # Check if product approximates identity
    identity = [[float(i == j) for j in range(2)] for i in range(2)]
    diff = matmul(A, inverse(A))
    print("diff from identity:", [[abs(diff[i][j] - identity[i][j]) for j in range(2)] for i in range(2)])
