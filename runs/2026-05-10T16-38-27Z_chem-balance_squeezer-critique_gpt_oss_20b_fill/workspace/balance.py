"""Chemical equation balancer.

This module provides a single function ``balance`` that takes an
unbalanced chemical equation string (e.g. ``"H2 + O2 -\u003e H2O"``) and
returns a tuple of two lists containing the smallest integer
coefficients for the left‑hand side and right‑hand side respectively.

The implementation parses a chemical formula, constructs a matrix that
corresponds to the element counts in each compound, and solves for the
integer null‑space vector using SymPy.  The result is normalised such
that all coefficients are positive, have no common divisor and are the
minimal integer solution.

Only standard library modules and `sympy` (which is a common\n
dependency in scientific projects) are used.
"""

from __future__ import annotations

from collections import defaultdict
from math import gcd
from typing import Dict, List, Tuple

# The package relies on `sympy`.  Import it lazily and provide a clear
# error message if it is missing.
try:
    from sympy import Matrix, lcm as sympy_lcm
except Exception as exc:  # pragma: no cover
    raise ImportError("SymPy is required for balance.py") from exc

# ---------- 1. Formula parsing utilities -------------------------------------

def _parse_formula(formula: str) -> Dict[str, int]:
    """Return a mapping of element symbols to the number of atoms.

    The parser understands:
    * Multi‑letter element symbols (e.g. ``Fe``).
    * Numeric subscripts following elements or parenthesised groups.
    * Parenthesised groups, optionally nested and repeated.

    Examples:
        >>> _parse_formula("H2O")
        {'H': 2, 'O': 1}
        >>> _parse_formula("Fe2(SO4)3")
        {'Fe': 2, 'S': 3, 'O': 12}
    """
    stack: List[defaultdict[int]] = [defaultdict(int)]
    i = 0
    n = len(formula)
    while i < n:
        ch = formula[i]
        if ch == "(":
            stack.append(defaultdict(int))
            i += 1
        elif ch == ")":
            i += 1
            start = i
            while i < n and formula[i].isdigit():
                i += 1
            repeat = int(formula[start:i] or "1")
            group_counts = stack.pop()
            for elem, cnt in group_counts.items():
                stack[-1][elem] += cnt * repeat
        elif ch.isupper():
            start = i
            i += 1
            while i < n and formula[i].islower():
                i += 1
            elem = formula[start:i]
            start_num = i
            while i < n and formula[i].isdigit():
                i += 1
            num = int(formula[start_num:i] or "1")
            stack[-1][elem] += num
        else:
            raise ValueError(f"Unexpected character '{ch}' in formula '{formula}'")
    if len(stack) != 1:
        raise ValueError("Mismatched parentheses in formula")
    return dict(stack[0])

# ---------- 2. Reaction balancing -------------------------------------

def balance(equation: str) -> Tuple[List[int], List[int]]:
    """Return balanced integer coefficients for a chemical equation.

    Parameters
    ----------
    equation:
        A string such as ``"H2 + O2 -\u003e H2O"``.
        The left‑hand side and right‑hand side must be separated by
        ``->``.  Compound separators can use ``+`` and trailing or
        leading whitespace is ignored.

    Returns
    -------
    tuple[list[int], list[int]]
        ``(lhs_coeffs, rhs_coeffs)`` – each integer list contains the
        smallest positive integer coefficients in the original order.

    Raises
    ------
    ValueError
        If the equation syntax is invalid or there is no unique
        balancing.
    """
    if "->" not in equation:
        raise ValueError("Equation must contain '-\u003e' separating left and right side")

    lhs_str, rhs_str = equation.split("->", 1)
    lhs_compounds = [c.strip() for c in lhs_str.split("+") if c.strip()]
    rhs_compounds = [c.strip() for c in rhs_str.split("+") if c.strip()]
    if not lhs_compounds or not rhs_compounds:
        raise ValueError("Both sides must contain at least one compound")

    all_compounds = lhs_compounds + rhs_compounds
    comp_counts: List[Dict[str, int]] = []
    for comp in all_compounds:
        comp_counts.append(_parse_formula(comp))

    elements = sorted({elem for counts in comp_counts for elem in counts})
    lhs_len = len(lhs_compounds)
    mat_rows = []
    for elem in elements:
        row = []
        for idx, counts in enumerate(comp_counts):
            if idx < lhs_len:
                row.append(counts.get(elem, 0))
            else:
                row.append(-counts.get(elem, 0))
        mat_rows.append(row)
    mat = Matrix(mat_rows)

    null_sp = mat.nullspace()
    if len(null_sp) != 1:
        raise ValueError("Ambiguous or unsolvable reaction – unique balancing not possible")
    vec = null_sp[0]

    lcm_den = sympy_lcm([term.q for term in vec])
    int_vec = [int(term * lcm_den) for term in vec]

    if any(c == 0 for c in int_vec):
        raise ValueError("Zero coefficient encountered – reaction cannot be balanced uniquely")

    # Ensure positivity
    if int_vec[0] < 0:
        int_vec = [-c for c in int_vec]

    common = gcd(*[abs(c) for c in int_vec])
    int_vec = [c // common for c in int_vec]

    return (int_vec[:lhs_len], int_vec[lhs_len:])

# ---------- 3. Simple CLI for manual experimentation ---------------------
if __name__ == "__main__":  # pragma: no cover
    import sys
    if len(sys.argv) < 2:
        print("Usage: python balance.py 'H2+O2 -\u003e H2O'")
        sys.exit(1)
    eq = sys.argv[1]
    try:
        lhs, rhs = balance(eq)
        print(f"{eq}\n  LHS: {lhs}\n  RHS: {rhs}")
    except Exception as exc:
        print(f"Error: {exc}")
