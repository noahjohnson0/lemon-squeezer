#!/usr/bin/env python3
"""Simple CRC implementations without external libraries.

This module provides two functions:

* ``crc32_ieee`` – CRC‑32 IEEE 802.3 / zlib algorithm.
* ``crc16_xmodem`` – CRC‑16 XMODEM algorithm.

The implementation uses a straightforward bit‑shifting loop, which is
sufficient for the command‑line tool use‑case.  No external modules
(binascii, zlib, crcmod, or any third‑party crate) are used.

The script can be used as a small command line utility:

```
$ python3 crc.py crc32 "Hello"          # prints the CRC‑32 of the string
$ python3 crc.py crc16 "Hello"          # prints the CRC‑16 XMODEM
```

Output is a lowercase hexadecimal string, zero‐padded to exactly
 8 characters for CRC‑32 and 4 characters for CRC‑16.
"""

from __future__ import annotations

import sys
from typing import Iterable

__all__ = ["crc32_ieee", "crc16_xmodem"]

# ---------------------------------------------------------------------------
# CRC‑32 IEEE 802.3 / zlib
# ---------------------------------------------------------------------------

def crc32_ieee(data: bytes) -> int:
    """Return CRC‑32 (IEEE 802.3 / zlib, reflected poly) of *data*.

    Parameters
    ----------
    data:
        Input bytes.

    Returns
    -------
    int
        The CRC value as an unsigned 32‑bit integer.

    Notes
    -----
    * Polynomial: 0x04C11DB7 (reflected 0xEDB88320).
    * Initial value: 0xFFFFFFFF.
    * Final XOR: 0xFFFFFFFF.
    * No reflection of input bytes – the algorithm handles bit‑order
      internally via shifting.
    * Implementation follows the classic table‑less algorithm.
    """

    crc = 0xFFFFFFFF
    for byte in data:
        # XOR the incoming byte with the low‑byte of the current CRC.
        crc ^= byte
        for _ in range(8):
            if crc & 1:
                crc = (crc >> 1) ^ 0xEDB88320
            else:
                crc >>= 1
    return crc ^ 0xFFFFFFFF

# ---------------------------------------------------------------------------
# CRC‑16 XMODEM
# ---------------------------------------------------------------------------

def crc16_xmodem(data: bytes) -> int:
    """Return CRC‑16 XMODEM of *data*.

    Parameters
    ----------
    data:
        Input bytes.

    Returns
    -------
    int
        The CRC value as an unsigned 16‑bit integer.

    Notes
    -----
    * Polynomial: 0x1021.
    * Initial value: 0x0000.
    * No reflection of input bytes.
    * No final XOR.
    """

    crc = 0x0000
    for byte in data:
        crc ^= (byte << 8)  # bring the byte into the upper 8 bits
        for _ in range(8):
            if crc & 0x8000:
                crc = ((crc << 1) ^ 0x1021) & 0xFFFF
            else:
                crc = (crc << 1) & 0xFFFF
    return crc

# ---------------------------------------------------------------------------
# CLI helper
# ---------------------------------------------------------------------------

def _print_hex(value: int, width: int) -> None:
    """Print *value* as a lowercase hex string of *width* digits.

    Parameters
    ----------
    value:
        The integer value to format.
    width:
        Number of hex digits to display (padded with leading zeros).
    """
    print(f"{value:0{width}x}")


def main(argv: Iterable[str] | None = None) -> int:
    """Command‑line interface.

    Usage
    -----
    ``python3 crc.py <crc32|crc16> <ascii_string>``
    """
    if argv is None:
        argv = sys.argv
    else:
        argv = list(argv)

    if len(argv) != 3:
        sys.stderr.write("Usage: python3 crc.py <crc32|crc16> <ascii_string>\n")
        return 1

    algo, text = argv[1], argv[2]
    data = text.encode("ascii", errors="strict")
    if algo == "crc32":
        val = crc32_ieee(data)
        _print_hex(val, 8)
    elif algo == "crc16":
        val = crc16_xmodem(data)
        _print_hex(val, 4)
    else:
        sys.stderr.write("Unknown algorithm: {}\n".format(algo))
        return 1
    return 0


if __name__ == "__main__":  # pragma: no cover
    sys.exit(main())
