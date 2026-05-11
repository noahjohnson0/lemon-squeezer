Implement the Vigenère cipher (classical polyalphabetic substitution).

The cipher uses a keyword that repeats over the plaintext. Each plaintext
letter is shifted by the corresponding key letter (A=0, B=1, ..., Z=25).

Rules:
- Only A-Z letters are encrypted. Spaces, punctuation, and digits pass through unchanged.
- Lowercase plaintext letters become lowercase ciphertext letters (case preserved).
- The key is uppercase A-Z (any length ≥ 1). Whitespace in the key is ignored.

Create `vigenere.py` exposing:

```python
def encrypt(plaintext: str, key: str) -> str: ...
def decrypt(ciphertext: str, key: str) -> str: ...
```

Examples:
- `encrypt("ATTACK AT DAWN", "LEMON")` → `"LXFOPV EF RNHR"`
- `decrypt("LXFOPV EF RNHR", "LEMON")` → `"ATTACK AT DAWN"`
- `encrypt("Hello, World!", "KEY")` → `"Rijvs, Uyvjn!"` (case preserved, punct unchanged)
- Both functions must raise ValueError if the key has no letters or contains non-letter, non-whitespace characters.

Save your code to `vigenere.py` in the workspace root.
