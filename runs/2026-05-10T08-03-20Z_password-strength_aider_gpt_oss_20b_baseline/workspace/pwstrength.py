#!/usr/bin/env python3
"""
Password strength scoring module.

Provides a single function `score(password: str) -> tuple[int, list[str]]`
that evaluates a password according to the following rules:

* 0 – terrible
* 1 – weak
* 2 – fair
* 3 – strong
* 4 – excellent

The function returns a tuple containing the numeric score and a list of
reason tokens that explain why the password received that score.
"""

from __future__ import annotations

import string
from typing import List, Tuple

# Hard‑coded blocklist of common passwords (case‑insensitive)
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


def _has_repeats(pwd: str) -> bool:
    """
    Return True if any character is repeated more than 3 times consecutively.
    """
    if not pwd:
        return False
    count = 1
    prev = pwd[0]
    for ch in pwd[1:]:
        if ch == prev:
            count += 1
            if count > 3:
                return True
        else:
            prev = ch
            count = 1
    return False


def _has_sequence(pwd: str) -> bool:
    """
    Return True if the password contains an ascending sequence of
    at least 4 consecutive characters (e.g. 'abcd', '1234', 'qwer').
    The check is case‑insensitive for alphabetic characters.
    """
    if len(pwd) < 4:
        return False

    # Normalize to lowercase for alphabetic comparison
    pwd_lower = pwd.lower()

    for i in range(len(pwd_lower) - 3):
        seq = pwd_lower[i : i + 4]
        # Check if all characters are alphabetic or digits
        if all(c.isalpha() or c.isdigit() for c in seq):
            # Verify ascending by 1 in Unicode code point
            if all(ord(seq[j + 1]) - ord(seq[j]) == 1 for j in range(3)):
                return True
    return False


def _class_counts(pwd: str) -> Tuple[bool, bool, bool, bool]:
    """
    Return a tuple of booleans indicating the presence of each
    character class: lower, upper, digit, symbol.
    """
    has_lower = has_upper = has_digit = has_symbol = False
    for ch in pwd:
        if ch.islower():
            has_lower = True
        elif ch.isupper():
            has_upper = True
        elif ch.isdigit():
            has_digit = True
        else:
            # Any non-alphanumeric character is considered a symbol
            has_symbol = True
    return has_lower, has_upper, has_digit, has_symbol


def score(password: str) -> Tuple[int, List[str]]:
    """
    Evaluate the strength of *password* and return a tuple
    `(score, reasons)`.

    *score* is an integer in the range 0..4 inclusive.
    *reasons* is a list of lowercase, hyphenated tokens that
    explain why the password received that score.  At least one
    token will be present for scores 0–3; for score 4 the list
    may be empty if the password meets all criteria.
    """
    reasons: List[str] = []

    pwd = password or ""
    length = len(pwd)

    # Basic checks that immediately set score to 0
    if length == 0 or length < 8:
        reasons.append("too-short")
    if pwd.lower() in _BLOCKLIST:
        reasons.append("in-blocklist")

    if reasons:
        # If any of the above conditions are true, score is 0
        return 0, reasons

    # Determine character classes
    has_lower, has_upper, has_digit, has_symbol = _class_counts(pwd)
    class_count = sum([has_lower, has_upper, has_digit, has_symbol])

    # Detect repeats and sequences
    repeats = _has_repeats(pwd)
    sequence = _has_sequence(pwd)

    # Build missing class tokens if needed
    if not has_lower:
        reasons.append("missing-lower")
    if not has_upper:
        reasons.append("missing-upper")
    if not has_digit:
        reasons.append("missing-digit")
    if not has_symbol:
        reasons.append("missing-symbol")

    # Add repeats and sequence tokens if applicable
    if repeats:
        reasons.append("repeats")
    if sequence:
        reasons.append("sequence")

    # Scoring logic
    if length >= 16 and class_count == 4 and not repeats and not sequence:
        # Excellent
        return 4, [r for r in reasons if r not in ("repeats", "sequence")]

    if length >= 12 and class_count >= 3 and not repeats:
        # Strong
        return 3, [r for r in reasons if r not in ("repeats", "sequence")]

    if (length >= 12 and class_count < 3) or (8 <= length <= 11 and class_count >= 3):
        # Fair
        return 2, reasons

    if 8 <= length <= 11 and class_count < 3:
        # Weak
        return 1, reasons

    # Fallback (should not normally reach here)
    return 0, reasons
