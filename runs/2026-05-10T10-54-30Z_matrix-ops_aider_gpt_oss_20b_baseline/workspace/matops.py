import numpy as np

def _check_square(M: list[list[float]]) -> None:
    """Ensure M is a square matrix."""
    n = len(M)
    if n == 0:
        raise ValueError("Matrix must be non-empty")
    for row in M:
        if len(row) != n:
            raise ValueError("Matrix must be square")
    return

def determinant(M: list[list[float]]) -> float:
    """
    Determinant of an n×n matrix via LU decomposition with partial pivoting.
    Raises ValueError if M is not square.
    """
    _check_square(M)
    n = len(M)
    A = np.array(M, dtype=float, copy=True)
    sign = 1.0

    for i in range(n):
        # Partial pivoting: find row with max abs value in column i
        pivot_row = i + np.argmax(np.abs(A[i:, i]))
        if np.abs(A[pivot_row, i]) < 1e-12:
            return 0.0  # singular matrix

        if pivot_row != i:
            # Swap rows
            A[[i, pivot_row]] = A[[pivot_row, i]]
            sign *= -1

        pivot = A[i, i]
        # Eliminate below
        for j in range(i + 1, n):
            factor = A[j, i] / pivot
            A[j, i:] -= factor * A[i, i:]

    det = sign * np.prod(np.diag(A))
    return float(det)

def inverse(M: list[list[float]]) -> list[list[float]]:
    """
    Invert an n×n matrix via Gauss-Jordan elimination with partial pivoting.
    Raises ValueError if M is not square or singular (|det| < 1e-10).
    """
    _check_square(M)
    n = len(M)
    A = np.array(M, dtype=float, copy=True)
    I = np.eye(n, dtype=float)

    for i in range(n):
        # Partial pivoting
        pivot_row = i + np.argmax(np.abs(A[i:, i]))
        if np.abs(A[pivot_row, i]) < 1e-12:
            raise ValueError("Matrix is singular and cannot be inverted")

        if pivot_row != i:
            A[[i, pivot_row]] = A[[pivot_row, i]]
            I[[i, pivot_row]] = I[[pivot_row, i]]

        pivot = A[i, i]
        # Normalize pivot row
        A[i] /= pivot
        I[i] /= pivot

        # Eliminate other rows
        for j in range(n):
            if j != i:
                factor = A[j, i]
                A[j] -= factor * A[i]
                I[j] -= factor * I[i]

    # Check determinant magnitude
    det = np.linalg.det(A)  # A is now identity, so det should be 1
    # But we need original determinant; compute from original matrix
    orig_det = determinant(M)
    if abs(orig_det) < 1e-10:
        raise ValueError("Matrix is singular (determinant too close to zero)")

    return I.tolist()

def matmul(A: list[list[float]], B: list[list[float]]) -> list[list[float]]:
    """
    Matrix product of A (m×k) and B (k×n).
    Raises ValueError on shape mismatch.
    """
    if not A or not B:
        raise ValueError("Input matrices must be non-empty")
    m = len(A)
    k = len(A[0])
    if any(len(row) != k for row in A):
        raise ValueError("All rows of A must have the same length")
    if len(B) != k:
        raise ValueError("Number of columns of A must equal number of rows of B")
    n = len(B[0])
    if any(len(row) != n for row in B):
        raise ValueError("All rows of B must have the same length")

    # Initialize result matrix with zeros
    result = np.zeros((m, n), dtype=float)

    for i in range(m):
        for j in range(n):
            s = 0.0
            for l in range(k):
                s += A[i][l] * B[l][j]
            result[i, j] = s

    return result.tolist()
