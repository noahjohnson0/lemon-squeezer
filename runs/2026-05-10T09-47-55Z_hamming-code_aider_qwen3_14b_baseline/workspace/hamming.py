def encode(data4: int) -> int:
    """Encode a 4-bit data value (0..15) into a 7-bit codeword.
    Standard Hamming(7,4): bit positions are 1-indexed [p1, p2, d1, p3, d2, d3, d4]
    where p1 covers (1,3,5,7), p2 covers (2,3,6,7), p3 covers (4,5,6,7).
    Return the 7-bit codeword as an int (0..127).
    Convention: data nibble bits (LSB-first) are d1=bit0, d2=bit1, d3=bit2, d4=bit3.
    Codeword bit ordering (LSB-first): bit0=p1, bit1=p2, bit2=d1, bit3=p3, bit4=d2, bit5=d3, bit6=d4."""
    d1 = (data4 >> 0) & 1
    d2 = (data4 >> 1) & 1
    d3 = (data4 >> 2) & 1
    d4 = (data4 >> 3) & 1
    p1 = d1 ^ d2 ^ d4
    p2 = d1 ^ d3 ^ d4
    p3 = d2 ^ d3 ^ d4
    return (p1 << 0) | (p2 << 1) | (d1 << 2) | (p3 << 3) | (d2 << 4) | (d3 << 5) | (d4 << 6)

def decode(code7: int) -> tuple[int, int]:
    """Decode a (possibly corrupted) 7-bit codeword.
    Returns (data4, error_bit_position) where error_bit_position is 0 if no error
    was detected, or the 1-indexed bit position (1..7) that was flipped (and which
    was corrected before extracting data4)."""
    p1 = (code7 >> 0) & 1
    p2 = (code7 >> 1) & 1
    d1 = (code7 >> 2) & 1
    p3 = (code7 >> 3) & 1
    d2 = (code7 >> 4) & 1
    d3 = (code7 >> 5) & 1
    d4 = (code7 >> 6) & 1

    s1 = (d1 ^ d2 ^ d4) ^ p1
    s2 = (d1 ^ d3 ^ d4) ^ p2
    s3 = (d2 ^ d3 ^ d4) ^ p3

    syndrome = (s3 << 2) | (s2 << 1) | s1
    error_bit_position = syndrome

    if error_bit_position == 0:
        data4 = (d1 << 0) | (d2 << 1) | (d3 << 2) | (d4 << 3)
        return (data4, 0)
    else:
        # Flip the error bit
        code7 ^= (1 << (error_bit_position - 1))
        # Re-extract the bits after correction
        p1 = (code7 >> 0) & 1
        p2 = (code7 >> 1) & 1
        d1 = (code7 >> 2) & 1
        p3 = (code7 >> 3) & 1
        d2 = (code7 >> 4) & 1
        d3 = (code7 >> 5) & 1
        d4 = (code7 >> 6) & 1
        data4 = (d1 << 0) | (d2 << 1) | (d3 << 2) | (d4 << 3)
        return (data4, error_bit_position)
