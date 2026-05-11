#!/usr/bin/env python3
"""
Utility to break a Caesar cipher using chi‑squared letter‑frequency analysis.
"""

from __future__ import annotations

import string
from collections import Counter
from typing import Tuple

# Expected English letter frequencies (percentages)
ENGLISH_FREQ = {
    'E': 12.7, 'T': 9.1, 'A': 8.2, 'O': 7.5, 'I': 7.0, 'N': 6.7,
    'S': 6.3, 'H': 6.1, 'R': 6.0, 'D': 4.3, 'L': 4.0, 'C': 2.8,
    'U': 2.8, 'M': 2.4, 'W': 2.4, 'F': 2.2, 'G': 2.0, 'Y': 2.0,
    'P': 1.9, 'B': 1.5, 'V': 1.0, 'K': 0.8, 'J': 0.15, 'X': 0.15,
    'Q': 0.10, 'Z': 0.07
}

ALPHABET = string.ascii_uppercase
ALPHABET_LEN = len(ALPHABET)
LETTER_TO_INDEX = {c: i for i, c in enumerate(ALPHABET)}


def _shift_char(c: str, shift: int) -> str:
    """Shift a single alphabetic character by `shift` positions, preserving case."""
    if c.isalpha():
        base = 'A' if c.isupper() else 'a'
        idx = (LETTER_TO_INDEX[c.upper()] + shift) % ALPHABET_LEN
        return chr(idx + ord(base))
    return c


def _decode(ciphertext: str, shift: int) -> str:
    """Decode the ciphertext using the given shift."""
    return ''.join(_shift_char(c, shift) for c in ciphertext)


def _chi_squared_score(text: str) -> float:
    """
    Compute the chi‑squared statistic for the letter frequencies in `text`
    compared to the expected English frequencies.
    """
    # Count only alphabetic characters, case‑insensitive
    letters = [c.upper() for c in text if c.isalpha()]
    total = len(letters)
    if total == 0:
        return float('inf')

    observed = Counter(letters)

    chi_sq = 0.0
    for letter, expected_pct in ENGLISH_FREQ.items():
        expected = expected_pct * total / 100.0
        observed_count = observed.get(letter, 0)
        chi_sq += (observed_count - expected) ** 2 / expected if expected else 0.0

    return chi_sq


def break_caesar(ciphertext: str) -> Tuple[int, str]:
    """
    Return (best_shift, decoded_plaintext) for the given ciphertext.
    The decoded plaintext preserves case and non‑letter characters.
    """
    best_shift = None
    best_score = float('inf')
    best_plaintext = ""

    for shift in range(ALPHABET_LEN):
        plaintext = _decode(ciphertext, shift)
        score = _chi_squared_score(plaintext)
        if score < best_score:
            best_score = score
            best_shift = shift
            best_plaintext = plaintext

    return best_shift, best_plaintext


if __name__ == "__main__":
    import sys

    if len(sys.argv) != 2:
        print("Usage: python break_caesar.py <ciphertext>")
        sys.exit(1)

    cipher = sys.argv[1]
    shift, plain = break_caesar(cipher)
    print(f"Best shift: {shift}")
    print(f"Plaintext: {plain}")
