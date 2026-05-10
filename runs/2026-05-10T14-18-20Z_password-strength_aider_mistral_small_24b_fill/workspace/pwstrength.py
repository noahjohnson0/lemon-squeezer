import re

def score(password: str) -> tuple[int, list[str]]:
    """Return (score, reasons) where:
      - score is an integer 0..4 inclusive (higher = stronger)
      - reasons is a list of lowercase strings explaining what's wrong (or what's strong)
    """
    blocklist = ["password", "123456", "12345678", "qwerty", "letmein", "admin", "welcome", "iloveyou", "monkey", "dragon"]
    reasons = []

    if not password:
        reasons.append("too-short")
        return 0, reasons

    if len(password) < 8:
        reasons.append("too-short")
        return 0, reasons

    if password.lower() in blocklist:
        reasons.append("in-blocklist")
        return 0, reasons

    has_lower = any(c.islower() for c in password)
    has_upper = any(c.isupper() for c in password)
    has_digit = any(c.isdigit() for c in password)
    has_symbol = any(not c.isalnum() for c in password)

    classes_used = sum([has_lower, has_upper, has_digit, has_symbol])

    if not has_lower:
        reasons.append("missing-lower")
    if not has_upper:
        reasons.append("missing-upper")
    if not has_digit:
        reasons.append("missing-digit")
    if not has_symbol:
        reasons.append("missing-symbol")

    if len(password) <= 11 and classes_used < 3:
        return 1, reasons

    if (len(password) >= 12 and classes_used < 3) or (8 <= len(password) <= 11 and classes_used >= 3):
        return 2, reasons

    if any(c * 4 in password for c in set(password)):
        reasons.append("repeats")

    sequences = [
        re.compile(r'(\d)\1\1\1'),
        re.compile(r'(a|b|c|d|e|f|g|h|i|j|k|l|m|n|o|p|q|r|s|t|u|v|w|x|y|z)\1\1\1'),
        re.compile(r'([A-Z])\1\1\1')
    ]

    if any(seq.search(password) for seq in sequences):
        reasons.append("sequence")

    if len(password) >= 12 and classes_used >= 3:
        return 3, reasons

    if len(password) >= 16 and classes_used == 4:
        return 4, reasons

    return 0, reasons
