Write `jsonptr.py` implementing **RFC 6901 JSON Pointer** evaluation plus a
subset of **RFC 6902 JSON Patch**. Implement the resolution and patch logic
yourself - do not use `jsonpatch`, `jsonpointer`, or any third-party library.
Standard library only.

Export exactly two functions:

```python
def resolve(doc, pointer: str):
    """Return the value in `doc` referenced by the RFC 6901 JSON Pointer string.
    See the rules below. Raise KeyError on any failed reference."""

def apply(doc, patch_ops: list[dict]):
    """Apply an RFC 6902 JSON Patch (a list of operation objects) to `doc` and
    return the NEW resulting document. Must be ATOMIC and must NOT mutate the
    input `doc`. Raise KeyError / ValueError / IndexError as specified."""
```

## resolve(doc, pointer) - RFC 6901

A JSON Pointer is a string of zero or more `/`-prefixed reference tokens.

1. **Empty string** `""` references the whole document: `resolve(doc, "")` is
   `doc` itself.
2. A pointer that is non-empty MUST begin with `/`. If it does not (e.g.
   `"foo"`), raise `ValueError`.
3. Split on `/`. Each token is **unescaped** in this exact order: first replace
   `~1` with `/`, then replace `~0` with `~`. (Order matters: `~01` must become
   `~1`, NOT `/`.)
4. For an **object** (dict), the token is a key. Missing key -> `KeyError`.
5. For an **array** (list):
   - The token must be either `-` or a non-negative integer with **no leading
     zeros** (so `"0"` is valid, `"01"` and `"00"` are not, `"-1"` is not).
     An invalid index token -> `KeyError`.
   - `-` always refers to the (nonexistent) element after the last and is NOT a
     valid resolve target -> `KeyError`.
   - An integer index that is out of range (>= len) -> `KeyError`.
6. Resolving into a scalar (you still have tokens left but the current value is
   not a dict/list) -> `KeyError`.
7. The literal key tokens matter: `resolve({"a/b": 1, "m~n": 2}, "/a~1b")` is
   `1`, and `resolve(..., "/m~0n")` is `2`. A key whose name is the empty
   string is reachable as `resolve({"": 5}, "/")` -> `5`.

## apply(doc, patch_ops) - RFC 6902 subset

`patch_ops` is a list of dicts. Support these ops: **add, remove, replace,
move, test**. Apply them in order to a deep copy. The function returns the new
document and MUST leave the caller's `doc` object completely unmodified, even
when an op fails partway through (atomicity - on any error, the original input
is untouched and the exception propagates).

Each op has a `"path"` (a JSON Pointer). `move` also has a `"from"` pointer.
`add`, `replace`, `test` have a `"value"`.

- **add**:
  - Into an object: set/overwrite the key at the final token.
  - Into an array at index `i`: **insert** before position `i` (shifting the
    rest right). `i == len` appends. `i > len` -> `IndexError`. The token `-`
    appends.
  - The parent (everything but the last token) must already exist, else
    `KeyError`.
  - `add` with `path == ""` replaces the whole document with `value`.
- **remove**: the target must exist (`KeyError` otherwise). Array remove deletes
  at that index and shifts left; `-` or out-of-range index -> `IndexError`.
- **replace**: the target must already exist (`KeyError` otherwise); same index
  rules as remove for arrays. Replaces in place (no shift).
- **move**: remove the value at `"from"`, then `add` it at `"path"`. The `from`
  location must exist. Per RFC 6902, `"from"` MUST NOT be a proper prefix of
  `"path"` (you cannot move a location into one of its own children) -> raise
  `ValueError`.
- **test**: succeed (no change) if the value at `"path"` **deep-equals**
  `"value"`; otherwise raise `ValueError`. Note `True`/`False` must NOT compare
  equal to `1`/`0` here (use a type-aware deep comparison so `test` of `1`
  against `True` fails), and `[1,2,3]` must equal `[1,2,3]` but not `[1,2]`.
- An unknown `"op"` -> `ValueError`.

## Performance

`resolve` must run in time proportional to the pointer depth, and `apply` must
not be quadratic in document size for shallow operations. A patch of a few
`replace`/`add`/`remove`/`test` ops against a document containing a list of
~200,000 elements must complete in well under the timeout. Do not deep-copy or
re-serialize the entire document once per token of every pointer.

Create only `jsonptr.py`. Do not run it.
