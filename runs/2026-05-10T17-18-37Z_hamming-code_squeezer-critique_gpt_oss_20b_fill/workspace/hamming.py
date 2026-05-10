"""Hamming(7,4) error correcting code.

Functions:
    encode(data4: int) -> int
        Encode a 4-bit data value into a 7-bit Hamming codeword.

    decode(code7: int) -> tuple[int, int]
        Decode (and correct) a possibly corrupted 7-bit codeword.

The implementation follows the standard Hamming(7,4) parity scheme with
1-indexed bit positions [p1, p2, d1, p3, d2, d3, d4].
The returned codeword and input data are represented as integers.
"""

from __future__ import annotations

__all__ = ["encode", "decode"]


def _parity(*bits: int) -> int:
    """Return XOR of given bits (each 0 or 1)."""
    result = 0
    for b in bits:
        result ^= b & 1
    return result


def encode(data4: int) -> int:
    """Encode a 4‑bit data value (0..15) into a 7‑bit Hamming codeword.

    The Hamming(7,4) code uses 1‑index positions [p1, p2, d1, p3, d2, d3, d4].
    Internally we work with 0‑index bit positions where bit 0 is the LSB.

    Parameters
    ----------
    data4 : int
        4‑bit integer value from 0 to 15.

    Returns
    -------
    int
        7‑bit integer codeword (0 .. 127).
    """
    if not (0 <= data4 < 16):
        raise ValueError("data4 must be a 4‑bit integer (0..15)")

    d1 = (data4 >> 0) & 1
    d2 = (data4 >> 1) & 1
    d3 = (data4 >> 2) & 1
    d4 = (data4 >> 3) & 1

    # Parity calculations
    p1 = _parity(d1, d2, d4)  # covers bits 3,5,7
    p2 = _parity(d1, d3, d4)  # covers bits 3,6,7
    p3 = _parity(d2, d3, d4)  # covers bits 5,6,7

    # Construct codeword (LSB first)
    code = 0
    code |= p1 << 0  # position 1
    code |= p2 << 1  # position 2
    code |= d1 << 2  # position 3
    code |= p3 << 3  # position 4
    code |= d2 << 4  # position 5
    code |= d3 << 5  # position 6
    code |= d4 << 6  # position 7
    return code


def decode(code7: int) -> tuple[int, int]:
    """Decode a 7‑bit Hamming codeword and correct a single‑bit error.

    Parameters
    ----------
    code7 : int
        7‑bit integer (0 .. 127) possibly containing a single bit error.

    Returns
    -------
    tuple[int, int]
        (data4, error_bit_position)
        ``data4`` is the decoded 4‑bit data value.
        ``error_bit_position`` is ``0`` when no error was detected,
        otherwise the 1‑indexed position of the bit that was flipped.
    """
    if not (0 <= code7 < 128):
        raise ValueError("code7 must be a 7‑bit integer (0..127)")

    # Extract bits from codeword
    bits = [(code7 >> i) & 1 for i in range(7)]  # bits[0] = p1 ... bits[6] = d4

    # Compute syndrome bits
    s1 = _parity(bits[0], bits[2], bits[4], bits[6])  # p1 covers 1,3,5,7
    s2 = _parity(bits[1], bits[2], bits[5], bits[6])  # p2 covers 2,3,6,7
    s3 = _parity(bits[3], bits[4], bits[5], bits[6])  # p3 covers 4,5,6,7

    syndrome = (s3 << 2) | (s2 << 1) | s1

    if syndrome != 0:
        # Correct the error by flipping the offending bit
        error_pos = syndrome - 1  # convert to 0‑index
        code7 ^= 1 << error_pos
        bits[error_pos] ^= 1  # keep local copy updated
    else:
        error_pos = -1  # no error

    # Extract data bits d1,d2,d3,d4 from corrected codeword
    d1 = bits[2]
    d2 = bits[4]
    d3 = bits[5]
    d4 = bits[6]

    data4 = (d4 << 3) | (d3 << 2) | (d2 << 1) | d1

    return data4, 0 if error_pos == -1 else syndrome

# Simple self‑check when the file is executed directly
if __name__ == "__main__":
    import sys
    for data in range(16):
        cw = encode(data)
        d, err = decode(cw)
        assert d == data and err == 0, (data, cw, d, err)
    print("All local self‑tests passed.")
