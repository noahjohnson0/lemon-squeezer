def score(password: str) -> tuple[int, list[str]]:
    """Return (score, reasons) where:
      - score is an integer 0..4 inclusive (higher = stronger)
      - reasons is a list of lowercase strings explaining what's wrong (or what's strong)
    """
    blocklist = ["password", "123456", "12345678", "qwerty", "letmein", "admin", "welcome", "iloveyou", "monkey", "dragon"]
    reasons = []
    score_val = 0

    # Check blocklist and length
    if not password or password.lower() in blocklist:
        if not password:
            reasons.append("too-short")
        else:
            reasons.append("in-blocklist")
        return (0, reasons)

    length = len(password)
    if length < 8:
        reasons.append("too-short")
        return (0, reasons)

    # Check character classes
    classes = set()
    for c in password:
        if c.islower():
            classes.add("lower")
        elif c.isupper():
            classes.add("upper")
        elif c.isdigit():
            classes.add("digit")
        else:
            classes.add("symbol")
    class_count = len(classes)

    # Check for score 4
    if length >= 16:
        if class_count == 4:
            # Check for repeats
            has_repeats = False
            for i in range(len(password) - 3):
                if password[i] == password[i+1] == password[i+2] == password[i+3]:
                    has_repeats = True
                    break
            if has_repeats:
                reasons.append("repeats")
            # Check for sequences
            sequences = ["abcd", "dcba", "1234", "4321", "wxyz", "zyxw", "qwer", "rewq"]
            has_sequence = False
            for seq in sequences:
                if seq in password:
                    has_sequence = True
                    break
            if has_sequence:
                reasons.append("sequence")
            # If both conditions are met, return score 4
            if not has_repeats and not has_sequence:
                return (4, reasons)
            else:
                return (4, reasons)
        else:
            # Missing a class
            for cls in ["lower", "upper", "digit", "symbol"]:
                if cls not in classes:
                    reasons.append(f"missing-{cls}")
            return (4, reasons)
    else:
        # Check for score 3
        if length >= 12:
            if class_count >= 3:
                # Check for repeats
                has_repeats = False
                for i in range(len(password) - 3):
                    if password[i] == password[i+1] == password[i+2] == password[i+3]:
                        has_repeats = True
                        break
                if has_repeats:
                    reasons.append("repeats")
                return (3, reasons)
            else:
                # Missing classes
                for cls in ["lower", "upper", "digit", "symbol"]:
                    if cls not in classes:
                        reasons.append(f"missing-{cls}")
                return (3, reasons)
        else:
            # Check for score 2 or 1
            if length >= 8 and length <= 11:
                if class_count >= 3:
                    return (2, reasons)
                else:
                    for cls in ["lower", "upper", "digit", "symbol"]:
                        if cls not in classes:
                            reasons.append(f"missing-{cls}")
                    return (1, reasons)
            else:
                # Length <8 already checked, so this shouldn't happen
                pass

    # If none of the above, return 0
    return (0, reasons)
