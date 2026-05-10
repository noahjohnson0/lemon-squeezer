Write `huffman.py` exporting Huffman coding primitives:

```python
def build_codes(text: str) -> dict[str, str]:
    """Build a Huffman code map from a string. Returns {char: bitstring} where each
    bitstring is a sequence of '0' and '1' chars. Tie-break deterministically (e.g.
    on count first, then lexicographic char) so output is reproducible."""

def encode(text: str, codes: dict[str, str]) -> str:
    """Encode text into a single bitstring (concatenation of per-char codes)."""

def decode(bits: str, codes: dict[str, str]) -> str:
    """Decode a bitstring back to text using the same codemap."""
```

Constraints:
- Pure stdlib (`heapq`, `collections.Counter` are fine).
- For single-char input, you may return a 1-bit code like `{'a': '0'}`.
- Empty input: `build_codes("")` returns `{}`, `encode("", {})` returns `""`, `decode("", {})` returns `""`.
- Round-trip: `decode(encode(s, build_codes(s)), build_codes(s)) == s` for any non-empty `s`.

Create only `huffman.py`. Don't run it.
