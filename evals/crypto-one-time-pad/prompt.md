Implement the One-Time Pad (OTP), the only provably-unbreakable classical cipher.

The OTP XORs every byte of plaintext with a key byte. If the key is truly
random, the same length as the message, used only once, and kept secret, the
ciphertext reveals no information about the plaintext.

Create `otp.py` exposing:

```python
def xor_encrypt(plaintext: bytes, key: bytes) -> bytes:
    """Encrypt by XORing each byte. Key must be exactly the same length as plaintext."""
    ...

def xor_decrypt(ciphertext: bytes, key: bytes) -> bytes:
    """Decrypt. Symmetric - same as xor_encrypt."""
    ...

def generate_key(length: int) -> bytes:
    """Return `length` cryptographically-random bytes using `secrets.token_bytes`."""
    ...

def hex_encode(data: bytes) -> str:
    """Return a colon-free lowercase hex string."""
    ...

def hex_decode(s: str) -> bytes: ...
```

Requirements:
- `xor_encrypt` and `xor_decrypt` must raise `ValueError` if key length ≠ plaintext length
- `generate_key` must use `secrets.token_bytes`, NOT `random` (random is not crypto-safe)
- For empty plaintext, return empty bytes (no error)

Save your code to `otp.py` in the workspace root.
