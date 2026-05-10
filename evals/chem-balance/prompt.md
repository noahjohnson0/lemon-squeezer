Write a Python module `balance.py` that balances chemical equations.

It must expose a single function:

```python
def balance(equation: str) -> tuple[list[int], list[int]]:
    """
    Take an unbalanced equation string like "H2 + O2 -> H2O".
    Return (lhs_coefficients, rhs_coefficients) as lists of POSITIVE integers
    in the smallest-integer form.

    Example:
        balance("H2 + O2 -> H2O") returns ([2, 1], [2])
        balance("CH4 + O2 -> CO2 + H2O") returns ([1, 2], [1, 2])
    """
```

Requirements:
- Parse formulas with multi-letter elements (e.g. `Fe`, `Cl`), digit subscripts (e.g. `H2O`, `Al2(SO4)3`), and parenthesised groups.
- Solve the balancing as a linear-algebra problem (build the element-count matrix, find a positive integer null-vector). You may use `numpy`, `scipy`, `sympy`, `fractions`, `math.gcd`, etc. — whatever you need. Do NOT hardcode answers per equation.
- Coefficients must be reduced to smallest positive integers (no common factor > 1).
- For unbalanceable input, raise `ValueError`.

Create only `balance.py`. Do not create test files or run anything.
