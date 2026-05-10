Write `re_match.py` exporting:

```python
def fullmatch(pattern: str, text: str) -> bool:
    """Implement a tiny regex engine that supports a subset of Python regex syntax.
    Return True iff `pattern` fully matches `text`.

    Supported metacharacters:
      . - any single character
      * - zero or more of preceding atom (greedy)
      + - one or more of preceding atom (greedy)
      ? - zero or one of preceding atom
      ^ - start of string (only meaningful at position 0)
      $ - end of string (only meaningful at end)
      [abc]   - character class
      [^abc]  - negated character class
      [a-z]   - character range
      \\d      - digit
      \\w      - word char (alnum + underscore)
      \\s      - whitespace

    Do NOT use Python's `re` module. Implement the matching yourself (recursive descent or NFA).

    Group capture, alternation `|`, backreferences are NOT required."""
```

Create only `re_match.py`. Don't run it.
