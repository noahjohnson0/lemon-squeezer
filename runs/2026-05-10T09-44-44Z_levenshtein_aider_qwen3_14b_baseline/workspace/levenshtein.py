def edit_distance(a: str, b: str) -> int:
    """Standard Levenshtein edit distance: minimum number of single-character
    insertions, deletions, or substitutions to transform a into b."""
    m, n = len(a), len(b)
    # Initialize a 2D DP table with dimensions (m+1) x (n+1)
    dp = [[0] * (n + 1) for _ in range(m + 1)]

    # Base cases: converting an empty string to another string
    for i in range(m + 1):
        dp[i][0] = i
    for j in range(n + 1):
        dp[0][j] = j

    # Fill the DP table
    for i in range(1, m + 1):
        for j in range(1, n + 1):
            if a[i - 1] == b[j - 1]:
                dp[i][j] = dp[i - 1][j - 1]
            else:
                dp[i][j] = 1 + min(dp[i - 1][j], dp[i][j - 1], dp[i - 1][j - 1])

    return dp[m][n]


def edit_path(a: str, b: str) -> list[tuple[str, str, str]]:
    """Return the list of operations as (op, src_char, dst_char) tuples where
    op is one of 'match', 'sub', 'ins', 'del'. The number of non-'match' ops
    must equal edit_distance(a, b). For 'match'/'sub', src_char and dst_char
    are the corresponding characters from a and b. For 'ins', src_char is ''.
    For 'del', dst_char is ''."""
    m, n = len(a), len(b)
    # Initialize a 2D DP table with dimensions (m+1) x (n+1)
    dp = [[0] * (n + 1) for _ in range(m + 1)]

    # Base cases: converting an empty string to another string
    for i in range(m + 1):
        dp[i][0] = i
    for j in range(n + 1):
        dp[0][j] = j

    # Fill the DP table
    for i in range(1, m + 1):
        for j in range(1, n + 1):
            if a[i - 1] == b[j - 1]:
                dp[i][j] = dp[i - 1][j - 1]
            else:
                dp[i][j] = 1 + min(dp[i - 1][j], dp[i][j - 1], dp[i - 1][j - 1])

    # Backtrack from dp[m][n] to dp[0][0] to reconstruct the path
    i, j = m, n
    path = []

    while i > 0 or j > 0:
        if i > 0 and j > 0 and a[i - 1] == b[j - 1]:
            # Characters match
            path.append(('match', a[i - 1], b[j - 1]))
            i -= 1
            j -= 1
        else:
            # Determine the operation that led to the current cell
            if i == 0:
                # Only possible operation is insertion
                path.append(('ins', '', b[j - 1]))
                j -= 1
            elif j == 0:
                # Only possible operation is deletion
                path.append(('del', a[i - 1], ''))
                i -= 1
            else:
                # Check which of the three possible operations was used
                if dp[i - 1][j] == dp[i][j] - 1:
                    # Deletion
                    path.append(('del', a[i - 1], ''))
                    i -= 1
                elif dp[i][j - 1] == dp[i][j] - 1:
                    # Insertion
                    path.append(('ins', '', b[j - 1]))
                    j -= 1
                elif dp[i - 1][j - 1] == dp[i][j] - 1:
                    # Substitution
                    path.append(('sub', a[i - 1], b[j - 1]))
                    i -= 1
                    j -= 1
                else:
                    # This should not happen with valid inputs
                    raise ValueError("Invalid DP table state during backtracking")

    # Reverse the path to get the correct order
    return path[::-1]
