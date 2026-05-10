def edit_distance(a: str, b: str) -> int:
    """Standard Levenshtein edit distance: minimum number of single-character
    insertions, deletions, or substitutions to transform a into b."""

    len_a = len(a)
    len_b = len(b)

    # Create a matrix to store the distances
    dp = [[0] * (len_b + 1) for _ in range(len_a + 1)]

    # Initialize the first row and column
    for i in range(len_a + 1):
        dp[i][0] = i
    for j in range(len_b + 1):
        dp[0][j] = j

    # Fill the matrix
    for i in range(1, len_a + 1):
        for j in range(1, len_b + 1):
            if a[i - 1] == b[j - 1]:
                cost = 0
            else:
                cost = 1
            dp[i][j] = min(dp[i - 1][j] + 1,      # Deletion
                           dp[i][j - 1] + 1,      # Insertion
                           dp[i - 1][j - 1] + cost)  # Substitution

    return dp[len_a][len_b]

def edit_path(a: str, b: str) -> list[tuple[str, str, str]]:
    """Return the list of operations as (op, src_char, dst_char) tuples where
    op is one of 'match', 'sub', 'ins', 'del'. The number of non-'match' ops
    must equal edit_distance(a, b). For 'match'/'sub', src_char and dst_char
    are the corresponding characters from a and b. For 'ins', src_char is ''.
    For 'del', dst_char is ''."""

    len_a = len(a)
    len_b = len(b)

    # Create a matrix to store the distances
    dp = [[0] * (len_b + 1) for _ in range(len_a + 1)]

    # Initialize the first row and column
    for i in range(len_a + 1):
        dp[i][0] = i
    for j in range(len_b + 1):
        dp[0][j] = j

    # Fill the matrix
    for i in range(1, len_a + 1):
        for j in range(1, len_b + 1):
            if a[i - 1] == b[j - 1]:
                cost = 0
            else:
                cost = 1
            dp[i][j] = min(dp[i - 1][j] + 1,      # Deletion
                           dp[i][j - 1] + 1,      # Insertion
                           dp[i - 1][j - 1] + cost)  # Substitution

    # Reconstruct the edit path
    i, j = len_a, len_b
    path = []

    while i > 0 or j > 0:
        if i > 0 and j > 0 and dp[i][j] == dp[i - 1][j - 1] + (a[i - 1] != b[j - 1]):
            if a[i - 1] == b[j - 1]:
                path.append(('match', a[i - 1], b[j - 1]))
            else:
                path.append(('sub', a[i - 1], b[j - 1]))
            i -= 1
            j -= 1
        elif i > 0 and dp[i][j] == dp[i - 1][j] + 1:
            path.append(('del', a[i - 1], ''))
            i -= 1
        else:
            path.append(('ins', '', b[j - 1]))
            j -= 1

    return path[::-1]
