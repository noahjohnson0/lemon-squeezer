Break a Caesar cipher using English letter-frequency analysis.

A Caesar cipher shifts every A-Z letter by the same amount (0-25); other
characters pass through. You must recover the shift WITHOUT knowing it.

Strategy: try all 26 possible shifts. For each candidate plaintext, score
how English-like it is by chi-squared distance against expected letter
frequencies. Pick the shift with the lowest chi-squared score.

Expected English letter frequencies (% - approximate):
  E=12.7  T=9.1  A=8.2  O=7.5  I=7.0  N=6.7  S=6.3  H=6.1  R=6.0
  D=4.3   L=4.0  C=2.8  U=2.8  M=2.4  W=2.4  F=2.2  G=2.0  Y=2.0
  P=1.9   B=1.5  V=1.0  K=0.8  J=0.15 X=0.15 Q=0.10 Z=0.07

Create `break_caesar.py` exposing:

```python
def break_caesar(ciphertext: str) -> tuple[int, str]:
    """Return (best_shift, decoded_plaintext) for the given ciphertext.
       The decoded plaintext preserves case and non-letter characters."""
    ...
```

Save your code to `break_caesar.py` in the workspace root. The rubric will
test 4 known cipher/plaintext pairs, mixing case and punctuation.
