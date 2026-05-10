import sys

def crc32_ieee(data: bytes) -> int:
    """CRC-32 IEEE 802.3 / zlib (reflected poly 0xEDB88320, init 0xFFFFFFFF, xor-out 0xFFFFFFFF).
    Returns a 32-bit integer."""
    crc = 0xFFFFFFFF
    for byte in data:
        crc ^= byte
        for _ in range(8):
            if crc & 1:
                crc = (crc >> 1) ^ 0xEDB88320
            else:
                crc >>= 1
    return crc ^ 0xFFFFFFFF

def crc16_xmodem(data: bytes) -> int:
    """CRC-16 XMODEM (poly 0x1021, init 0x0000, no reflection, no xor-out). Returns 16-bit int."""
    crc = 0
    for byte in data:
        crc ^= byte << 8
        for _ in range(8):
            if crc & 0x8000:
                crc = (crc << 1) ^ 0x1021
            else:
                crc <<= 1
    return crc & 0xFFFF

def main():
    if len(sys.argv) != 3:
        print("Usage: python3 crc.py <crc32|crc16> <ascii_string>")
        sys.exit(1)

    crc_type, data = sys.argv[1], sys.argv[2].encode('utf-8')

    if crc_type == 'crc32':
        result = crc32_ieee(data)
        print(f"{result:08x}")
    elif crc_type == 'crc16':
        result = crc16_xmodem(data)
        print(f"{result:04x}")
    else:
        print("Invalid CRC type. Use 'crc32' or 'crc16'.")
        sys.exit(1)

if __name__ == '__main__':
    main()
