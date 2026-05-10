def edit_distance(a: str, b: str) -> int:
    """Standard Levenshtein edit distance: minimum number of single-character
    insertions, deletions, or substitutions to transform a into b."""
    m, n = len(a), len(b)
    dp = [[0] * (n + 1) for _ in range(m + 1)]
    for i in range(m + 1):
        dp[i][0] = i
    for j in range(n + 1):
        dp[0][j] = j
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
    dp = [[0] * (n + 1) for _ in range(m + 1)]
    for i in range(m + 1):
        dp[i][0] = i
    for j in range(n + 1):
        dp[0][j] = j
    for i in range(1, m + 1):
        for j in range(1, n + 1):
            if a[i - 1] == b[j - 1]:
                dp[i][j] = dp[i - 1][j - 1]
            else:
                dp[i][j] = 1 + min(dp[i - 1][j], dp[i][j - 1], dp[i - 1][j - 1])
    current_i, current_j = m, n
    operations = []
    while current_i > 0 or current_j > 0:
        if current_i == 0:
            for _ in range(current_j):
                operations.append(('ins', '', b[current_j - 1]))
                current_j -= 1
            break
        if current_j == 0:
            for _ in range(current_i):
                operations.append(('del', a[current_i - 1], ''))
                current_i -= 1
            break
        if a[current_i - 1] == b[current_j - 1]:
            operations.append(('match', a[current_i - 1], b[current_j - 1]))
            current_i -= 1
            current_j -= 1
        else:
            if dp[current_i][current_j] == dp[current_i - 1][current_j] + 1:
                operations.append(('del', a[current_i - 1], ''))
                current_i -= 1
            elif dp[current_i][current_j] == dp[current_i][current_j - 1] + 1:
                operations.append(('ins', '', b[current_j - 1]))
                current_j -= 1
            else:
                operations.append(('sub', a[current_i - 1], b[current_j - 1]))
                current_i -= 1
                current_j -= 1
    operations.reverse()
    return operations
