"""
Base64 encoder/decoder (RFC 4648) without using the standard `base64` module.

This module provides two functions:

* `encode(data: bytes) -> str`    Encode a bytes object to a Base64 ASCII string,
  including the standard '=' padding.

* `decode(s: str) -> bytes`       Decode a Base64 ASCII string back to bytes.
  The function is tolerant of whitespace (spaces, tabs, newlines) but raises
  `ValueError` if an illegal character is found.

The implementation uses only bitwise operations and a fixed mapping
character set.
"""

from __future__ import annotations

_ALPHA = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
# Build a lookup table for decoding: mapping from ordinal to 6‑bit value.
decode_table = {c: i for i, c in enumerate(_ALPHA)}


+def encode(data: bytes) -> str:
+    """Encode *data* to a Base64 string.
+
+    Parameters
+    ----------
+    data:
+        Bytes to encode.
+
+    Returns
+    -------
+    str
+        The Base64 representation of *data*, including ``=`` padding
+        characters when necessary.
+    """
+    if not data:
+        return ""
+
+    # Process input in 3‑byte chunks.
+    result_chars = []
+    # Pad input with zeros so that its length is a multiple of 3.
+    padding_needed = (-len(data)) % 3
+    if padding_needed:
+        data_padded = data + b"\0" * padding_needed
+    else:
+        data_padded = data
+
+    for i in range(0, len(data_padded), 3):
+        chunk = data_padded[i:i+3]
+        # Pack three bytes into a 24‑bit integer.
+        combined = (chunk[0] << 16) | (chunk[1] << 8) | chunk[2]
+        # Extract four 6‑bit groups and map to Base64 alphabet.
+        result_chars.append(_ALPHA[(combined >> 18) & 0x3F])
+        result_chars.append(_ALPHA[(combined >> 12) & 0x3F])
+        result_chars.append(_ALPHA[(combined >> 6) & 0x3F])
+        result_chars.append(_ALPHA[combined & 0x3F])
+
+    # Replace the last 1 or 2 characters with padding '=' where needed.
+    if padding_needed:
+        result_chars[-padding_needed:] = ['='] * padding_needed
+
+    return "".join(result_chars)
+
+
+def decode(s: str) -> bytes:
+    """Decode a Base64 string *s* back to bytes.
+
+    Whitespace characters (space, tab, carriage return, newline) are
+    ignored.  The function validates that the string contains only
+    characters from the Base64 alphabet or the padding character ``=``.
+    Padding is only allowed at the end of the string and at most two
+    characters may be used.
+
+    Parameters
+    ----------
+    s:
+        Base64 encoded string.
+
+    Returns
+    -------
+    bytes
+        Decoded byte sequence.
+
+    Raises
+    ------
+    ValueError
+        If the input contains an illegal character, incorrect padding,
+        or a length that is not a multiple of 4.
+    """
+    # Remove any whitespace.
+    cleaned = "".join(c for c in s if not c.isspace())
+    if not cleaned:
+        return b""
+
+    # All Base64 strings must have a length that is a multiple of 4.
+    if len(cleaned) % 4 != 0:
+        raise ValueError("Invalid Base64 length; must be a multiple of 4")
+
+    # Validate padding.
+    padding = 0
+    if cleaned.endswith("=="):
+        padding = 2
+    elif cleaned.endswith("="):
+        padding = 1
+    # Ensure padding appears only at the end.
+    if padding:
+        if cleaned[-padding:] != '=' * padding or '=' in cleaned[:-padding]:
+            raise ValueError("Invalid padding position")
+    # Ensure the rest of the string contains only valid Base64 characters.
+    for ch in cleaned.rstrip('='):
+        if ch not in decode_table:
+            raise ValueError(f"Illegal character in Base64 input: {ch!r}")
+
+    result_bytes = bytearray()
+    bits_collected = 0
+    accumulator = 0
+
+    for ch in cleaned:
+        if ch == '=':
+            # Padding; ignore processing of padding bytes.
+            break
+        value = decode_table[ch]
+        accumulator = (accumulator << 6) | value
+        bits_collected += 6
+        if bits_collected >= 8:
+            bits_collected -= 8
+            result_bytes.append((accumulator >> bits_collected) & 0xFF)
+    return bytes(result_bytes)
+
+
+__all__ = ["encode", "decode"]
+
*** End of File ***
