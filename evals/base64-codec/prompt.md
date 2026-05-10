Write `base64codec.py` exporting two functions implementing standard RFC 4648 Base64 (NOT URL-safe, NOT base32).

```python
def encode(data: bytes) -> str:
    """Encode bytes to a Base64 ASCII string. Includes '=' padding when needed."""

def decode(s: str) -> bytes:
    """Decode a Base64 ASCII string back to bytes. Tolerates whitespace; rejects invalid chars by raising ValueError."""
```

Constraints:
- DO NOT import `base64` or any third-party module. Implement manually using bit shifts.
- Standard alphabet: `ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/`
- Round-trip must be exact for any byte input.

Create only `base64codec.py`. Don't run it.
