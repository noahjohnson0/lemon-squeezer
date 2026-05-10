def score(password: str) -> tuple[int, list[str]]:
    """Return (score, reasons) where:
      - score is an integer 0..4 inclusive (higher = stronger)
      - reasons is a list of lowercase strings explaining what's wrong (or what's strong)
    """
    blocklist = ["password", "123456", "12345678", "qwerty", "letmein", "admin", "welcome", "iloveyou", "monkey", "dragon"]
    reasons = []
    score = 0

    # Check for blocklist or too short
    if not password or len(password) < 8 or password.lower() in blocklist:
        if len(password) < 8:
            reasons.append("too-short")
        else:
            reasons.append("in-blocklist")
        return (0, reasons)

    # Check for length and character classes
    lower = any(c.islower() for c in password)
    upper = any(c.isupper() for c in password)
    digit = any(c.isdigit() for c in password)
    symbol = any(not c.isalnum() for c in password)
    classes = sum([lower, upper, digit, symbol])

    # Check for weak (score 1)
    if 8 <= len(password) <= 11 and classes < 3:
        score = 1
        if not lower:
            reasons.append("missing-lower")
        if not upper:
            reasons.append("missing-upper")
        if not digit:
            reasons.append("missing-digit")
        if not symbol:
            reasons.append("missing-symbol")
        return (score, reasons)

    # Check for fair (score 2)
    if len(password) >= 12 and classes < 3:
        score = 2
        if not lower:
            reasons.append("missing-lower")
        if not upper:
            reasons.append("missing-upper")
        if not digit:
            reasons.append("missing-digit")
        if not symbol:
            reasons.append("missing-symbol")
        return (score, reasons)

    # Check for fair (score 2) - length 8-11 with >=3 classes
    if 8 <= len(password) <= 11 and classes >= 3:
        score = 2
        return (score, reasons)

    # Check for strong (score 3)
    if len(password) >= 12 and classes >= 3:
        # Check for consecutive repeats of 3 or more
        for i in range(len(password) - 2):
            if password[i] == password[i+1] == password[i+2]:
                reasons.append("repeats")
                break
        else:
            # No repeats, check for sequences
            sequences = ["1234", "abcd", "qwer", "wxyz", "123456", "abcdef", "ghijkl", "mnopqr", "stuvwx", "yzabc", "12345", "67890"]
            for seq in sequences:
                if seq in password:
                    reasons.append("sequence")
                    break
            else:
                score = 3
                return (score, reasons)
        score = 3
        return (score, reasons)

    # Check for excellent (score 4)
    if len(password) >= 16 and classes == 4:
        # Check for consecutive repeats of 3 or more
        for i in range(len(password) - 2):
            if password[i] == password[i+1] == password[i+2]:
                reasons.append("repeats")
                break
        else:
            # Check for sequences
            sequences = ["1234", "abcd", "qwer", "wxyz", "123456", "abcdef", "ghijkl", "mnopqr", "stuvwx", "yzabc", "12345", "67890"]
            for seq in sequences:
                if seq in password:
                    reasons.append("sequence")
                    break
            else:
                score = 4
                return (score, reasons)
    return (score, reasons)
