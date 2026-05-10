def determinant(M: list[list[float]]) -> float:
    """Determinant of an n×n matrix via expansion-by-minors.
    Raise ValueError if not square."""
    if not is_square(M):
        raise ValueError("Matrix must be square")
    n = len(M)
    if n == 1:
        return M[0][0]
    if n == 2:
        return M[0][0] * M[1][1] - M[0][1] * M[1][0]
    det = 0.0
    for col in range(n):
        sign = 1 if (col % 2 == 0) else -1
        minor = [[M[i][j] for j in range(n) if j != col] for i in range(1, n)]
        det += sign * M[0][col] * determinant(minor)
    return det


def inverse(M: list[list[float]]) -> list[list[float]]:
    """Invert an n×n matrix via Gauss-Jordan elimination.
    Raise ValueError if singular (|det| < 1e-10) or not square."""
    if not is_square(M):
        raise ValueError("Matrix must be square")
    n = len(M)
    det = determinant(M)
    if abs(det) < 1e-10:
        raise ValueError("Matrix is singular")
    # Create augmented matrix [M | I]
    aug = [[M[i][j] if j < n else 0.0 for j in range(2 * n)] for i in range(n)]
    for i in range(n):
        aug[i][i + n] = 1.0

    # Perform Gauss-Jordan elimination
    for col in range(n):
        # Find pivot row
        pivot_row = None
        for r in range(col, n):
            if abs(aug[r][col]) > 1e-10:
                pivot_row = r
                break
        if pivot_row is None:
            raise ValueError("Matrix is singular")
        # Swap current row with pivot row
        aug[col], aug[pivot_row] = aug[pivot_row], aug[col]
        # Normalize pivot row
        pivot_val = aug[col][col]
        for j in range(col, 2 * n):
            aug[col][j] /= pivot_val
        # Eliminate other rows
        for r in range(n):
            if r != col and abs(aug[r][col]) > 1e-10:
                factor = aug[r][col]
                for j in range(col, 2 * n):
                    aug[r][j] -= factor * aug[col][j]

    # Extract inverse matrix
    inverse_matrix = [[aug[i][j] for j in range(n, 2 * n)] for i in range(n)]
    return inverse_matrix


def matmul(A: list[list[float]], B: list[list[float]]) -> list[list[float]]:
    """Matrix product. Raise ValueError on shape mismatch."""
    rows_A = len(A)
    cols_A = len(A[0]) if rows_A > 0 else 0
    rows_B = len(B)
    cols_B = len(B[0]) if rows_B > 0 else 0
    if cols_A != rows_B:
        raise ValueError("Matrix dimensions do not match for multiplication")
    result = [[0.0 for _ in range(cols_B)] for _ in range(rows_A)]
    for i in range(rows_A):
        for j in range(cols_B):
            for k in range(cols_A):
                result[i][j] += A[i][k] * B[k][j]
    return result


def is_square(M: list[list[float]]) -> bool:
    """Check if a matrix is square (n×n)."""
    if not M:
        return False
    n = len(M)
    return all(len(row) == n for row in M)
