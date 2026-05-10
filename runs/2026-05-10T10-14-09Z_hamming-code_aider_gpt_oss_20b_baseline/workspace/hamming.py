"""
Hamming(7,4) error‑correcting code primitives.

The implementation follows the standard Hamming(7,4) construction with
bit positions (1-indexed) [p1, p2, d1, p3, d2, d3, d4].
The codeword is returned as a 7‑bit integer (0..127) with the
least‑significant bit representing position 1.

Functions
---------
encode(data4: int) -> int
    Encode a 4‑bit data value into a 7‑bit Hamming codeword.

decode(code7: int) -> tuple[int, int]
    Decode a (possibly corrupted) 7‑bit codeword, correcting a single‑bit
    error if present. Returns the original 4‑bit data and the 1‑indexed
    error bit position (0 if no error).
"""

from __future__ import annotations
from typing import Tuple


def encode(data4: int) -> int:
    """
    Encode a 4‑bit data value (0..15) into a 7‑bit Hamming(7,4) codeword.

    The data nibble bits are interpreted LSB‑first:
        d1 = bit0, d2 = bit1, d3 = bit2, d4 = bit3

    The codeword bit ordering (LSB‑first) is:
        bit0 = p1, bit1 = p2, bit2 = d1, bit3 = p3,
        bit4 = d2, bit5 = d3, bit6 = d4

    Returns
    -------
    int
        The 7‑bit codeword (0..127).
    """
    # Mask to 4 bits to avoid accidental overflow
    data4 &= 0xF

    d1 = (data4 >> 0) & 1
    d2 = (data4 >> 1) & 1
    d3 = (data4 >> 2) & 1
    d4 = (data4 >> 3) & 1

    # Parity bits
    p1 = d1 ^ d2 ^ d4          # covers positions 1,3,5,7
    p2 = d1 ^ d3 ^ d4          # covers positions 2,3,6,7
    p3 = d2 ^ d3 ^ d4          # covers positions 4,5,6,7

    # Assemble codeword
    code = (
        (p1 << 0) |
        (p2 << 1) |
        (d1 << 2) |
        (p3 << 3) |
        (d2 << 4) |
        (d3 << 5) |
        (d4 << 6)
    )
    return code


def decode(code7: int) -> Tuple[int, int]:
    """
    Decode a (possibly corrupted) 7‑bit Hamming(7,4) codeword.

    Parameters
    ----------
    code7 : int
        The 7‑bit codeword (0..127). Bits beyond the 7 least significant
        bits are ignored.

    Returns
    -------
    tuple[int, int]
        (data4, error_bit_position)
        * data4 : the decoded 4‑bit data value (0..15)
        * error_bit_position : 0 if no error was detected,
          otherwise the 1‑indexed bit position (1..7) that was flipped
          and corrected before extracting data4.
    """
    # Ensure we only work with 7 bits
    code = code7 & 0x7F

    # Extract bits
    b0 = (code >> 0) & 1  # p1
    b1 = (code >> 1) & 1  # p2
    b2 = (code >> 2) & 1  # d1
    b3 = (code >> 3) & 1  # p3
    b4 = (code >> 4) & 1  # d2
    b5 = (code >> 5) & 1  # d3
    b6 = (code >> 6) & 1  # d4

    # Compute syndrome bits
    s1 = b0 ^ b2 ^ b4 ^ b6          # parity of positions 1,3,5,7
    s2 = b1 ^ b2 ^ b5 ^ b6          # parity of positions 2,3,6,7
    s3 = b3 ^ b4 ^ b5 ^ b6          # parity of positions 4,5,6,7

    # Syndrome as a 3‑bit number (s3 is MSB)
    syndrome = (s3 << 2) | (s2 << 1) | s1

    error_position = syndrome  # 0 means no error

    if error_position:
        # Flip the erroneous bit (convert 1‑indexed to 0‑indexed)
        code ^= (1 << (error_position - 1))

    # After correction, extract data bits
    d1 = (code >> 2) & 1
    d2 = (code >> 4) & 1
    d3 = (code >> 5) & 1
    d4 = (code >> 6) & 1

    data4 = d1 | (d2 << 1) | (d3 << 2) | (d4 << 3)

    return data4, error_position
