Write `hamming.py` exporting Hamming(7,4) error-correcting code primitives:

```python
def encode(data4: int) -> int:
    """Encode a 4-bit data value (0..15) into a 7-bit codeword.
    Standard Hamming(7,4): bit positions are 1-indexed [p1, p2, d1, p3, d2, d3, d4]
    where p1 covers (1,3,5,7), p2 covers (2,3,6,7), p3 covers (4,5,6,7).
    Return the 7-bit codeword as an int (0..127).
    Convention: data nibble bits (LSB-first) are d1=bit0, d2=bit1, d3=bit2, d4=bit3.
    Codeword bit ordering (LSB-first): bit0=p1, bit1=p2, bit2=d1, bit3=p3, bit4=d2, bit5=d3, bit6=d4."""

def decode(code7: int) -> tuple[int, int]:
    """Decode a (possibly corrupted) 7-bit codeword.
    Returns (data4, error_bit_position) where error_bit_position is 0 if no error
    was detected, or the 1-indexed bit position (1..7) that was flipped (and which
    was corrected before extracting data4)."""
```

Constraints:
- Must correct any single-bit flip in the 7-bit codeword.
- `decode(encode(x))` must equal `(x, 0)` for all `x in range(16)`.
- `decode(encode(x) ^ (1 << k))` must equal `(x, k+1)` for k in 0..6.

Create only `hamming.py`. Don't run it.
