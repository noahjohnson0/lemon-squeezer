# base64codec.py
# Implements RFC 4648 Base64 encoding/decoding without using the standard library.

# Standard Base64 alphabet
_ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
# Reverse lookup table for decoding
_DECODE_MAP = {c: i for i, c in enumerate(_ALPHABET)}

def encode(data: bytes) -> str:
    """
    Encode bytes to a Base64 ASCII string. Includes '=' padding when needed.
    """
    if not isinstance(data, (bytes, bytearray)):
        raise TypeError("data must be bytes or bytearray")

    encoded_chars = []
    # Process input in chunks of 3 bytes
    for i in range(0, len(data), 3):
        chunk = data[i:i+3]
        # Pad chunk to 3 bytes with zeros for processing
        b = [0, 0, 0]
        for j in range(len(chunk)):
            b[j] = chunk[j]
        # Combine into 24-bit integer
        twenty_four = (b[0] << 16) | (b[1] << 8) | b[2]
        # Extract four 6-bit groups
        c1 = (twenty_four >> 18) & 0x3F
        c2 = (twenty_four >> 12) & 0x3F
        c3 = (twenty_four >> 6) & 0x3F
        c4 = twenty_four & 0x3F
        # Append corresponding characters
        encoded_chars.append(_ALPHABET[c1])
        encoded_chars.append(_ALPHABET[c2])
        # Handle padding based on chunk length
        if len(chunk) == 1:
            encoded_chars.append('=')
            encoded_chars.append('=')
        elif len(chunk) == 2:
            encoded_chars.append(_ALPHABET[c3])
            encoded_chars.append('=')
        else:
            encoded_chars.append(_ALPHABET[c3])
            encoded_chars.append(_ALPHABET[c4])

    return ''.join(encoded_chars)


def decode(s: str) -> bytes:
    """
    Decode a Base64 ASCII string back to bytes.
    Tolerates whitespace; rejects invalid chars by raising ValueError.
    """
    if not isinstance(s, str):
        raise TypeError("s must be a string")

    # Remove all whitespace characters
    s_clean = ''.join(s.split())
    if len(s_clean) == 0:
        return b''

    # Length must be a multiple of 4
    if len(s_clean) % 4 != 0:
        raise ValueError("Invalid Base64 string length")

    # Count padding
    padding = 0
    if s_clean.endswith('=='):
        padding = 2
    elif s_clean.endswith('='):
        padding = 1

    # Validate padding position
    if padding and s_clean[-padding:] != '=' * padding:
        raise ValueError("Invalid padding in Base64 string")

    decoded_bytes = bytearray()

    # Process each 4-character block
    for i in range(0, len(s_clean), 4):
        block = s_clean[i:i+4]
        # Map each character to its 6-bit value
        sextets = []
        for j, ch in enumerate(block):
            if ch == '=':
                # Padding should only appear at the end of the block
                if j < 2:
                    raise ValueError("Padding in invalid position")
                sextets.append(0)
            else:
                if ch not in _DECODE_MAP:
                    raise ValueError(f"Invalid character '{ch}' in Base64 string")
                sextets.append(_DECODE_MAP[ch])

        # Combine into 24-bit integer
        twenty_four = (sextets[0] << 18) | (sextets[1] << 12) | (sextets[2] << 6) | sextets[3]

        # Extract original bytes
        decoded_bytes.append((twenty_four >> 16) & 0xFF)
        if block[2] != '=':
            decoded_bytes.append((twenty_four >> 8) & 0xFF)
        if block[3] != '=':
            decoded_bytes.append(twenty_four & 0xFF)

    # Remove padding bytes if any were added during decoding
    if padding:
        decoded_bytes = decoded_bytes[:-padding]

    return bytes(decoded_bytes)
