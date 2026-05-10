def score(password: str) -> tuple[int, list[str]]:
    """Return (score, reasons) where:
      - score is an integer 0..4 inclusive (higher = stronger)
      - reasons is a list of lowercase strings explaining what's wrong (or what's strong)
    """
    blocklist = [
        "password", "123456", "12345678", "qwerty", "letmein",
        "admin", "welcome", "iloveyou", "monkey", "dragon"
    ]

    reasons = []
    score = 0

    # Check for empty password or length < 8
    if not password:
        reasons.append("too-short")
        return (0, reasons)
    elif len(password) < 8:
        reasons.append("too-short")
        score = 0
    else:
        score = 1

    # Check for blocklist
    if password.lower() in blocklist:
        reasons.append("in-blocklist")
        return (0, reasons)

    # Check character classes
    has_lower = any(c.islower() for c in password)
    has_upper = any(c.isupper() for c in password)
    has_digit = any(c.isdigit() for c in password)
    has_symbol = any(not c.isalnum() for c in password)

    if not has_lower:
        reasons.append("missing-lower")
    if not has_upper:
        reasons.append("missing-upper")
    if not has_digit:
        reasons.append("missing-digit")
    if not has_symbol:
        reasons.append("missing-symbol")

    # Check for repeats
    repeat_count = 1
    for i in range(1, len(password)):
        if password[i] == password[i - 1]:
            repeat_count += 1
        else:
            repeat_count = 1

        if repeat_count > 3:
            reasons.append("repeats")
            break

    # Check for sequences
    sequences = ["1234", "abcd", "qwer", "wxyz"]
    for seq in sequences:
        if seq in password.lower():
            reasons.append("sequence")
            break

    # Determine score based on length and character classes
    if len(password) >= 8 and len(password) <= 11:
        if sum([has_lower, has_upper, has_digit, has_symbol]) < 3:
            score = 1
        else:
            score = 2
    elif len(password) >= 12:
        if sum([has_lower, has_upper, has_digit, has_symbol]) < 3:
            score = 2
        elif "repeats" not in reasons and "sequence" not in reasons:
            score = 3
        else:
            score = 2

    # Excellent score for length >= 16 with all classes and no repeats or sequences
    if len(password) >= 16 and sum([has_lower, has_upper, has_digit, has_symbol]) == 4 and "repeats" not in reasons and "sequence" not in reasons:
        score = 4

    return (score, reasons)
