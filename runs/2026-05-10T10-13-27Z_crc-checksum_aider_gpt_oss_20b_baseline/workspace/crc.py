#!/usr/bin/env python3
"""
CRC implementations and CLI.

Functions:
    crc32_ieee(data: bytes) -> int
    crc16_xmodem(data: bytes) -> int

CLI:
    python3 crc.py <crc32|crc16> <ascii_string>
"""

import sys

def crc32_ieee(data: bytes) -> int:
    """
    CRC-32 IEEE 802.3 / zlib (reflected poly 0xEDB88320, init 0xFFFFFFFF, xor-out 0xFFFFFFFF).
    Returns a 32-bit integer.
    """
    poly = 0xEDB88320
    crc = 0xFFFFFFFF
    for byte in data:
        crc ^= byte
        for _ in range(8):
            if crc & 1:
                crc = (crc >> 1) ^ poly
            else:
                crc >>= 1
    crc ^= 0xFFFFFFFF
    return crc & 0xFFFFFFFF

def crc16_xmodem(data: bytes) -> int:
    """
    CRC-16 XMODEM (poly 0x1021, init 0x0000, no reflection, no xor-out).
    Returns a 16-bit integer.
    """
    poly = 0x1021
    crc = 0x0000
    for byte in data:
        crc ^= (byte << 8)
        for _ in range(8):
            if crc & 0x8000:
                crc = ((crc << 1) ^ poly) & 0xFFFF
            else:
                crc = (crc << 1) & 0xFFFF
    return crc & 0xFFFF

def _print_usage():
    print("Usage: python3 crc.py <crc32|crc16> <ascii_string>")

def main():
    if len(sys.argv) != 3:
        _print_usage()
        sys.exit(1)

    mode = sys.argv[1].lower()
    text = sys.argv[2]
    data = text.encode('ascii', errors='ignore')

    if mode == "crc32":
        result = crc32_ieee(data)
        print(f"{result:08x}")
    elif mode == "crc16":
        result = crc16_xmodem(data)
        print(f"{result:04x}")
    else:
        _print_usage()
        sys.exit(1)

if __name__ == "__main__":
    main()
