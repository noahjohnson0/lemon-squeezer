import sys

def crc32_ieee(data: bytes) -> int:
    """CRC-32 IEEE 802.3 / zlib (reflected poly 0xEDB88320, init 0xFFFFFFFF, xor-out 0xFFFFFFFF).
    Returns a 32-bit integer."""
    crc = 0xFFFFFFFF
    for byte in data:
        reversed_byte = 0
        for i in range(8):
            reversed_byte <<= 1
            reversed_byte |= (byte >> i) & 1
        for _ in range(8):
            if crc & 0x80000000:
                crc = (crc << 1) ^ 0xEDB88320
            else:
                crc = (crc << 1)
            crc &= 0xFFFFFFFF
    crc ^= 0xFFFFFFFF
    return crc

def crc16_xmodem(data: bytes) -> int:
    """CRC-16 XMODEM (poly 0x1021, init 0x0000, no reflection, no xor-out). Returns 16-bit int."""
    crc = 0x0000
    for byte in data:
        for _ in range(8):
            if crc & 0x8000:
                crc = (crc << 1) ^ 0x1021
            else:
                crc = (crc << 1)
            crc &= 0xFFFF
    return crc

if __name__ == '__main__':
    if len(sys.argv) != 3:
        print("Usage: python3 crc.py <crc32|crc16> <ascii_string>")
        sys.exit(1)
    crc_type = sys.argv[1]
    data = sys.argv[2].encode('ascii')
    if crc_type == 'crc32':
        result = crc32_ieee(data)
    elif crc_type == 'crc16':
        result = crc16_xmodem(data)
    else:
        print("Invalid CRC type")
        sys.exit(1)
    if crc_type == 'crc32':
        hex_str = format(result, '08x')
    else:
        hex_str = format(result, '04x')
    print(hex_str)
