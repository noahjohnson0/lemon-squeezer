Write `crc.py` exporting two CRC implementations:

```python
def crc32_ieee(data: bytes) -> int:
    """CRC-32 IEEE 802.3 / zlib (reflected poly 0xEDB88320, init 0xFFFFFFFF, xor-out 0xFFFFFFFF).
    Returns a 32-bit integer."""

def crc16_xmodem(data: bytes) -> int:
    """CRC-16 XMODEM (poly 0x1021, init 0x0000, no reflection, no xor-out). Returns 16-bit int."""
```

Also provide a CLI: `python3 crc.py <crc32|crc16> <ascii_string>` that prints lowercase hex (no `0x`),
zero-padded to 8 (CRC-32) or 4 (CRC-16) hex chars.

Constraints:
- DO NOT import `binascii`, `zlib`, or `crcmod`. Implement the bit-shift loop yourself.

Create only `crc.py`. Don't run it.
