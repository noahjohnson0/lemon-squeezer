"""Password strength scoring module.

This module provides a :func:`score` function that evaluates a password and
returns a 0‑4 score along with a list of reasons describing what is
strengthening or weakening the password.

The design follows the specification given in the prompt and is kept
self‑contained so it can be used by other projects.
"""

from __future__ import annotations

import re
from typing import Tuple, List

# Hard‑coded blocklist of common passwords.
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

# Pre‑compiled regexes for detecting repeated characters.
_REPEATS_RE = re.compile(r"(.)\1{3,}")

# Regex for detecting ascending or descending sequences of length 4.
# We will use a custom function instead of regex to handle both digits and letters.

# Helper functions


def _char_classes(pw: str) -> Tuple[bool, bool, bool, bool]:
    """Return boolean flags for (lower, upper, digit, symbol)."""
    lower = any(c.islower() for c in pw)
    upper = any(c.isupper() for c in pw)
    digit = any(c.isdigit() for c in pw)
    symbol = any(not c.isalnum() for c in pw)
    return lower, upper, digit, symbol


def _count_repeats(pw: str) -> bool:
    """Return True if a character repeats 4 or more times consecutively."""
    return bool(_REPEATS_RE.search(pw))


def _contains_sequence(pw: str) -> bool:
    """Detect any four‑character ascending or descending sequence.

    The sequence detection works for digits and letters.  For example:
    ``abcd``, ``1234``, ``qwer``, ``edcb``.
    """
    n = len(pw)
    if n < 4:
        return False
    for i in range(n - 3):
        seq = pw[i : i + 4]
        # Ensure all chars are of the same type: all digits or all letters.
        if seq.isdigit() or seq.isalpha():
            diffs = [ord(seq[j + 1]) - ord(seq[j]) for j in range(3)]
            if all(d == 1 for d in diffs) or all(d == -1 for d in diffs):
                return True
    return False


def score(password: str) -> Tuple[int, List[str]]:
    """Score the *password* and return a tuple ``(score, reasons)``.

    Args:
        password: The password string to evaluate.

    Returns:
        A tuple containing:

        * ``score``: An integer from 0 to 4 inclusive.
        * ``reasons``: A list of lowercase hyphenated strings explaining
          what is wrong or what makes the password strong.
    """

    reasons: List[str] = []

    pw = password
    length = len(pw)

    # 0 - terrible
    if length == 0 or length < 8 or pw.lower() in _BLOCKLIST:
        # Determine specific reasons.
        if length < 8:
            reasons.append("too-short")
        if pw.lower() in _BLOCKLIST:
            reasons.append("in-blocklist")
        return 0, reasons

    lower, upper, digit, symbol = _char_classes(pw)
    classes_used = [lower, upper, digit, symbol]
    num_classes = sum(classes_used)

    # 1 - weak
    if 8 <= length <= 11 and num_classes < 3:
        # Append missing class tokens if desired.
        if not lower:
            reasons.append("missing-lower")
        if not upper:
            reasons.append("missing-upper")
        if not digit:
            reasons.append("missing-digit")
        if not symbol:
            reasons.append("missing-symbol")
        return 1, reasons

    # 2 - fair
    if (length >= 12 and num_classes < 3) or (8 <= length <= 11 and num_classes >= 3):
        if not lower:
            reasons.append("missing-lower")
        if not upper:
            reasons.append("missing-upper")
        if not digit:
            reasons.append("missing-digit")
        if not symbol:
            reasons.append("missing-symbol")
        return 2, reasons

    # 3 - strong
    if length >= 12 and num_classes >= 3 and not _count_repeats(pw):
        # Add missing class tokens if there's any.
        if not lower:
            reasons.append("missing-lower")
        if not upper:
            reasons.append("missing-upper")
        if not digit:
            reasons.append("missing-digit")
        if not symbol:
            reasons.append("missing-symbol")
        return 3, reasons

    # 4 - excellent
    if (
        length >= 16
        and num_classes == 4
        and not _count_repeats(pw)
        and not _contains_sequence(pw)
    ):
        return 4, reasons

    # If we reach here, defaults to previous tier rules but ensure we return something.
    # We'll fall back to the highest tier that matches the partial criteria.
    # This occurs when length>=12, all classes present, but repeats or sequence present.
    if length >= 12 and num_classes >= 3:
        if _count_repeats(pw):
            reasons.append("repeats")
        if _contains_sequence(pw):
            reasons.append("sequence")
        return 2, reasons
    if length >= 8 and num_classes >= 3:
        if _count_repeats(pw):
            reasons.append("repeats")
        if _contains_sequence(pw):
            reasons.append("sequence")
        return 1, reasons

    # Default to 0 if nothing matched? Actually unreachable.
    return 0, reasons

*** End of file ***
