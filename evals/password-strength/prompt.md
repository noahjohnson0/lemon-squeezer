Write `pwstrength.py` exporting one function:

```python
def score(password: str) -> tuple[int, list[str]]:
    """Return (score, reasons) where:
      - score is an integer 0..4 inclusive (higher = stronger)
      - reasons is a list of lowercase strings explaining what's wrong (or what's strong)
    """
```

Scoring rules:
- **0 - terrible.** Empty, OR length < 8, OR is in this hardcoded blocklist of common passwords:
  `["password", "123456", "12345678", "qwerty", "letmein", "admin", "welcome", "iloveyou", "monkey", "dragon"]`
  (case-insensitive match against the whole password).
- **1 - weak.** Length 8-11 AND uses < 3 of the four character classes (lower / upper / digit / non-alphanumeric).
- **2 - fair.** Length ≥ 12 with < 3 classes; OR length 8-11 with ≥ 3 classes.
- **3 - strong.** Length ≥ 12 with ≥ 3 classes AND no character is repeated more than 3 times consecutively.
- **4 - excellent.** Length ≥ 16 with all 4 classes AND no repeat-3 AND no obvious sequence (e.g. `1234`, `abcd`, `qwer`, `wxyz`) of length ≥ 4 anywhere in the password.

The `reasons` list should contain at least one of these tokens when applicable (lowercase, hyphenated):
- `"too-short"`, `"in-blocklist"`, `"missing-lower"`, `"missing-upper"`, `"missing-digit"`, `"missing-symbol"`, `"repeats"`, `"sequence"`.

Create only `pwstrength.py`. Don't run it.
