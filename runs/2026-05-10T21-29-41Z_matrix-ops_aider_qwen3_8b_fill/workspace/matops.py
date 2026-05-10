def determinant(M: list[list[float]]) -> float:
    """Determinant of an n×n matrix via Gaussian elimination.
    Raise ValueError if not square."""
    n = len(M)
    if any(len(row) != n for row in M):
        raise ValueError("Matrix is not square")
    
    mat = [row[:] for row in M]
    det = 1.0
    swaps = 0

    for i in range(n):
        pivot = None
        for j in range(i, n):
            if abs(mat[j][i]) > 1e-10:
                pivot = j
                break
        if pivot is None:
            return 0.0

        if pivot != i:
            mat[i], mat[pivot] = mat[pivot], mat[i]
            swaps += 1

        pivot_val = mat[i][i]
        for j in range(i + 1, n):
            factor = mat[j][i] / pivot_val
            for k in range(i, n):
                mat[j][k] -= factor * mat[i][k]

    for i in range(n):
        det *= mat[i][i]
    det *= (-1) ** swaps
    return det


def inverse(M: list[list[float]]) -> list[list[float]]:
    """Invert an n×n matrix via Gauss-Jordan elimination.
    Raise ValueError if singular (|det| < 1e-10) or not square."""
    n = len(M)
    if any(len(row) != n for row in M):
        raise ValueError("Matrix is not square")

    aug = [row + [0.0] * n for row in M]
    for i in range(n):
        pivot = None
        for j in range(i, n):
            if abs(aug[j][i]) > 1e-10:
                pivot = j
                break
        if pivot is None:
            raise ValueError("Matrix is singular")

        aug[i], aug[pivot] = aug[pivot], aug[i]

        pivot_val = aug[i][i]
        if abs(pivot_val) < 1e-10:
            raise ValueError("Matrix is singular")

        for j in range(i, n):
            aug[i][j] /= pivot_val

        for k in range(n):
            if k != i and abs(aug[k][i]) > 1e-10:
                factor = aug[k][i]
                for j in range(i, n):
                    aug[k][j] -= factor * aug[i][j]

    inverse_matrix = [row[n:] for row in aug]
    return inverse_matrix


def matmul(A: list[list[float]], B: list[list[float]]) -> list[list[float]]:
    """Matrix product. Raise ValueError on shape mismatch."""
    rows_A = len(A)
    cols_A = len(A[0])
    rows_B = len(B)
    cols_B = len(B[0])

    if cols_A != rows_B:
        raise ValueError("Shape mismatch")

    result = [[0.0 for _ in range(cols_B)] for _ in range(rows_A)]

    for i in range(rows_A):
        for j in range(cols_B):
            for k in range(cols_A):
                result[i][j] += A[i][k] * B[k][j]

    return result
