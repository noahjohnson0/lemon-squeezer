def encode(data: bytes) -> str:
    """Encode bytes to a Base64 ASCII string. Includes '=' padding when needed."""
    alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    output = b""
    for i in range(0, len(data), 3):
        byte1 = data[i] << 16
        if i + 1 < len(data):
            byte2 = (data[i + 1] & 0xFF) << 8
            byte3 = data[i + 2]
        else:
            byte2 = 0
            byte3 = 0
        output += bytes([byte1 >> 18, (byte1 >> 12) & 0x3F, (byte1 >> 6) & 0x3F])
        if i + 1 < len(data):
            output += bytes([byte2 >> 10, byte2 & 0x3F])
    padding = len(data) % 3
    if padding == 1:
        output += b"=="
    elif padding == 2:
        output += b"="
    return "".join(alphabet[i >> 6] + alphabet[(i >> 6) & 63] + alphabet[i & 63] for i in range(len(output) * 8 // 24))

def decode(s: str) -> bytes:
    """Decode a Base64 ASCII string back to bytes. Tolerates whitespace; rejects invalid chars by raising ValueError."""
    s = s.replace(" ", "")
    if len(s) % 4 != 0:
        raise ValueError("Invalid input length")
    alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    output = b""
    for i in range(0, len(s), 4):
        chunk = s[i:i + 4]
        if not all(c in alphabet for c in chunk):
            raise ValueError("Invalid character in input string")
        byte1 = (alphabet.index(chunk[0]) << 18) | (alphabet.index(chunk[1]) << 12) | (alphabet.index(chunk[2]) << 6)
        output += bytes([byte1 >> 16, byte1 & 0xFF])
        if len(chunk) == 4:
            byte2 = (alphabet.index(chunk[3]) << 10) | alphabet.index(chunk[2])
            output += bytes([byte2 >> 8, byte2 & 0xFF])
    return output
