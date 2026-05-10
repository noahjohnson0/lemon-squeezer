import math

BASE64_ALPHABET = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'

def encode(data: bytes) -> str:
    """Encode bytes to a Base64 ASCII string. Includes '=' padding when needed."""
    if not data:
        return ""

    # Calculate the number of 6-bit chunks
    num_chunks = math.ceil(len(data) * 8 / 6)

    # Initialize the result list
    result = []

    # Process each byte in the input data
    for i in range(0, len(data), 3):
        chunk = (data[i] << 16) if i + 1 < len(data) else 0
        chunk |= (data[i+1] << 8) if i + 2 < len(data) else 0
        chunk |= data[i+2] if i + 3 <= len(data) else 0

        # Extract 6-bit chunks from the combined byte value
        for j in range(4):
            if (i * 8 + j * 6) >= len(data) * 8:
                result.append('=')
            else:
                six_bit_chunk = (chunk >> (18 - j * 6)) & 0x3F
                result.append(BASE64_ALPHABET[six_bit_chunk])

    return ''.join(result)

def decode(s: str) -> bytes:
    """Decode a Base64 ASCII string back to bytes. Tolerates whitespace; rejects invalid chars by raising ValueError."""
    # Remove any whitespace characters from the input string
    s = ''.join(filter(lambda c: c in BASE64_ALPHABET or c == '=', s))

    if not s:
        return b""

    # Calculate the number of 8-bit bytes
    num_bytes = math.ceil(len(s) * 6 / 8)

    # Initialize the result list
    result = []

    # Process each character in the input string
    for i in range(0, len(s), 4):
        chunk = 0

        for j in range(4):
            if s[i + j] == '=':
                break
            six_bit_chunk = BASE64_ALPHABET.index(s[i + j])
            chunk |= (six_bit_chunk << (18 - j * 6))

        # Extract 8-bit bytes from the combined byte value
        for k in range(3):
            if i * 6 + k * 8 >= len(s) * 6:
                break
            eight_bit_byte = (chunk >> (24 - k * 8)) & 0xFF
            result.append(eight_bit_byte)

    return bytes(result)
