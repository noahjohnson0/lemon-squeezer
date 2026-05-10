"""Password strength scoring based on specified rules.

The module exports a single function `score(password: str) -> tuple[int, list[str]]`.

Score range: 0 – 4.
Reasons are a list of lower‑case hyphenated tokens explaining weaknesses or strengths.
"""

import string
from typing import Tuple, List

# Hard‑coded list of commonly used passwords (case‑insensitive comparison).
_BLOCKLIST = {
    "password",
    "123456",
    "12345678",
    "qwerty",
    "letmein",
    "admin",
    "welcome",
    "iloveyou",
    "monkey",
    "dragon",
}

# Sequences that are considered obvious and reduce strength.
_OBVIOUS_SEQUENCES = {
    "1234",
    "abcd",
    "qwer",
    "wxyz",
}


def _has_repeats(pw: str) -> bool:
    """Return True if any character repeats more than 3 times consecutively."""
    if len(pw) < 4:
        return False
    count = 1
    for i in range(1, len(pw)):
        if pw[i] == pw[i - 1]:
            count += 1
            if count > 3:
                return True
        else:
            count = 1
    return False


def _has_sequence(pw: str) -> bool:
    """Check if any of the obvious sequences appears as a substring."""
    lowered = pw.lower()
    for seq in _OBVIOUS_SEQUENCES:
        if seq in lowered:
            return True
    return False


def _class_counts(pw: str) -> Tuple[int, bool, bool, bool, bool]:
    """Return counts for each character class.

    Returns a tuple: (total_classes, has_lower, has_upper, has_digit, has_symbol).
    """
    has_lower = has_upper = has_digit = has_symbol = False
    for ch in pw:
        if ch.islower():
            has_lower = True
        elif ch.isupper():
            has_upper = True
        elif ch.isdigit():
            has_digit = True
        else:
            # non‑alphanumeric symbols
            has_symbol = True
    classes = sum([has_lower, has_upper, has_digit, has_symbol])
    return classes, has_lower, has_upper, has_digit, has_symbol


def score(password: str) -> Tuple[int, List[str]]:
    """Return a tuple (score, reasons).

    The ``score`` is an integer from 0 to 4 inclusive, calculated according to the
    specifications. ``reasons`` is a list of lowercase hyphenated tokens that
    explain the score (e.g. ``"too-short"``). At least one token is included when
    applicable.
    """
    reasons: List[str] = []
    pwd = password
    length = len(pwd)

    # 0 – terrible checks
    if length == 0 or length < 8:
        reasons.append("too-short")
        return 0, reasons
    if pwd.lower() in _BLOCKLIST:
        reasons.append("in-blocklist")
        return 0, reasons

    # Character class information
    classes, has_lower, has_upper, has_digit, has_symbol = _class_counts(pwd)
    if not has_lower:
        reasons.append("missing-lower")
    if not has_upper:
        reasons.append("missing-upper")
    if not has_digit:
        reasons.append("missing-digit")
    if not has_symbol:
        reasons.append("missing-symbol")

    # Repeat and sequence checks
    repeats = _has_repeats(pwd)
    if repeats:
        reasons.append("repeats")
    sequence = _has_sequence(pwd)
    if sequence:
        reasons.append("sequence")

    # --- Scoring logic based on remaining conditions ---
    # Weak (1)
    if 8 <= length <= 11 and classes < 3:
        score_val = 1
    # Fair (2) cases
    elif length >= 12 and classes < 3:
        score_val = 2
    elif 8 <= length <= 11 and classes >= 3:
        score_val = 2
    # Strong / Excellent
    else:  # length >= 12 and classes >= 3
        if repeats:
            # Repeats downgrade to 2
            score_val = 2
        else:
            if length >= 16 and classes == 4 and not sequence:
                score_val = 4
            else:
                score_val = 3
    return score_val, reasons


# If this module is executed directly, run a quick manual smoke test.
if __name__ == "__main__":  # pragma: no cover
    test_pwds = [
        "",
        "abc",
        "Password1",
        "StrongPass!123",
        "VeryStrongP@sswordThatIsLongEnough",
        "1234abcd",
        "aaaaAAA11111!!",
    ]
    for pw in test_pwds:
        s, r = score(pw)
        print(f"{pw:35} -> score {s}, reasons: {r}")
