ALPHABET = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'

def encode(data: bytes) -> str:
    """Encode bytes to a Base64 ASCII string. Includes '=' padding when needed."""
    encoded_chars = []
    for i in range(0, len(data), 3):
        chunk = data[i:i+3]
        bits = int.from_bytes(chunk, byteorder='big')
        
        # Encode the 24-bit chunk into four Base64 characters
        encoded_chars.append(ALPHABET[bits >> 18])
        encoded_chars.append(ALPHABET[(bits >> 12) & 0x3F])
        if len(chunk) >= 2:
            encoded_chars.append(ALPHABET[(bits >> 6) & 0x3F])
        else:
            encoded_chars.append('=')
        if len(chunk) == 3:
            encoded_chars.append(ALPHABET[bits & 0x3F])
        else:
            encoded_chars.append('=')

    return ''.join(encoded_chars)


def decode(s: str) -> bytes:
    """Decode a Base64 ASCII string back to bytes. Tolerates whitespace; rejects invalid chars by raising ValueError."""
    s = s.replace(' ', '').replace('\n', '')
    
    if len(s) % 4 != 0 or '=' in s and (len(s) - s.count('=')) % 4 != 0:
        raise ValueError("Invalid base64 string length")
    
    decoded_bytes = bytearray()
    for i in range(0, len(s), 4):
        chunk = s[i:i+4]
        
        # Convert Base64 characters to bits
        bits = (ALPHABET.index(chunk[0]) << 18) | (ALPHABET.index(chunk[1]) << 12)
        if len(chunk) > 2:
            bits |= ALPHABET.index(chunk[2]) << 6
        else:
            bits >>= 6
        if len(chunk) == 4:
            bits |= ALPHABET.index(chunk[3])
        
        # Convert bits to bytes and append to result
        decoded_bytes.extend(bits.to_bytes(3 - chunk.count('='), byteorder='big'))

    return bytes(decoded_bytes)
