"""
Module for balancing chemical equations.

Provides a single function ``balance`` that takes an unbalanced equation
string, e.g. ``"H2 + O2 -> H2O"`` and returns two lists of positive
integers representing the smallest-integer coefficients for the left
hand side (LHS) and the right hand side (RHS) of the equation.

The implementation parses chemical formulas with element symbols,
numeric sub‑scripts and parenthesised groups, builds an element
count matrix, and solves the resulting homogeneous linear system
using SymPy's exact arithmetic.
"""

from __future__ import annotations

import re
from math import gcd
from functools import reduce

from sympy import Matrix, Rational, lcm as sympy_lcm

__all__ = ["balance"]


# ---------------------------------------------------------------------------
# Parsing utilities
# ---------------------------------------------------------------------------

def _tokenize(formula: str):
    """Yield tokens from a chemical formula.

    Tokens are one of the following:

    * element symbols (e.g. ``H``, ``Fe``)
    * opening parenthesis ``(``
    * closing parenthesis ``)``
    * integer sub‑scripts
    """
    pattern = r"([A-Z][a-z]?)|([0-9]+)|[()]"
    for match in re.finditer(pattern, formula):
        symbol, number = match.group(1), match.group(2)
        if symbol:
            yield symbol
        elif number:
            yield number
        else:
            yield match.group(0)


def _parse_molecule(formula: str) -> dict[str, int]:
    """Parse a single molecule formula into a dictionary of element counts.

    Supports nested parenthesised groups and integer sub‑scripts.
    """
    stack: list[dict[str, int]] = [dict()]
    tokens = list(_tokenize(formula))
    i = 0
    while i < len(tokens):
        tok = tokens[i]
        if tok == "(":
            stack.append(dict())
            i += 1
        elif tok == ")":
            group = stack.pop()
            # Grab multiplier (if any)
            mult = 1
            if i + 1 < len(tokens) and tokens[i + 1].isdigit():
                mult = int(tokens[i + 1])
                i += 1
            for el, n in group.items():
                stack[-1][el] = stack[-1].get(el, 0) + n * mult
            i += 1
        elif re.match(r"[A-Z][a-z]?", tok):
            element = tok
            # Grab sub‑script (if any)
            mult = 1
            if i + 1 < len(tokens) and tokens[i + 1].isdigit():
                mult = int(tokens[i + 1])
                i += 1
            stack[-1][element] = stack[-1].get(element, 0) + mult
            i += 1
        else:  # should be a digit, but that would be handled in previous step
            # This situation occurs when a number is not following an
            # element or a parenthesis, which is syntactically incorrect.
            raise ValueError(f"Unexpected token '{tok}' in formula '{formula}'.")
    if len(stack) != 1:
        raise ValueError(f"Unbalanced parentheses in formula '{formula}'.")
    return stack[0]


# ---------------------------------------------------------------------------
# Main balancing logic
# ---------------------------------------------------------------------------

def balance(equation: str) -> tuple[list[int], list[int]]:
    """Balance a chemical reaction.

    Parameters
    ----------
    equation:
        A reaction string containing molecules separated by ``+`` on each
        side and the separating arrow ``->`` (case‑insensitive).  The
        function tolerates surrounding white‑space.

    Returns
    -------
    tuple[list[int], list[int]]
        ``(lhs_coeffs, rhs_coeffs)`` where each list contains integers ≥
        1 and the coefficients are reduced to their smallest integers.

    Raises
    ------
    ValueError
        If the equation cannot be balanced or if a valid solution would
        require a non‑positive coefficient.
    """

    # Sanitize and split LHS / RHS
    if "->" not in equation and "--" not in equation and ">=" not in equation:
        raise ValueError("Equation must contain '->' to separate sides.")

    lhs_str, rhs_str = [side.strip() for side in equation.split("->", 1)] if "->" in equation else [side.strip() for side in equation.split("--", 1)] if "--" in equation else [side.strip() for side in equation.split(">=", 1)]
    lhs_mols = [mol.strip() for mol in lhs_str.split("+") if mol.strip()]
    rhs_mols = [mol.strip() for mol in rhs_str.split("+") if mol.strip()]

    all_mols = lhs_mols + rhs_mols

    # Parse all molecules and gather the set of elements
    parsed = [_parse_molecule(mol) for mol in all_mols]
    elements = sorted({el for mol in parsed for el in mol})

    # Build the matrix with LHS columns positive and RHS columns negative
    rows = []
    for el in elements:
        row = []
        for dict_ in parsed[: len(lhs_mols)]:
            row.append(dict_.get(el, 0))
        for dict_ in parsed[len(lhs_mols) :]:
            row.append(-dict_.get(el, 0))  # RHS counts are negated
        rows.append(row)
    mat = Matrix(rows)

    nullspace = mat.nullspace()
    if not nullspace:
        raise ValueError("Cannot balance the given equation")

    # Grab first basis vector (exact arithmetic)
    vec = nullspace[0]

    # Convert to integer vector – multiply by LCM of denominators
    denom_lcm = sympy_lcm([elem.q for elem in vec])
    int_vec = [abs(int(elem * denom_lcm)) for elem in vec]

    # Separate into LHS and RHS lists
    lhs_coeffs: list[int] = int_vec[: len(lhs_mols)]
    rhs_coeffs: list[int] = int_vec[len(lhs_mols) :]

    # Reduce coefficients to smallest integers
    def _gcd_multi(numbers: list[int]) -> int:
        return reduce(gcd, numbers)

    all_coeffs = lhs_coeffs + rhs_coeffs
    common_gcd = _gcd_multi(all_coeffs)
    lhs_coeffs = [c // common_gcd for c in lhs_coeffs]
    rhs_coeffs = [c // common_gcd for c in rhs_coeffs]

    if any(c <= 0 for c in lhs_coeffs + rhs_coeffs):
        raise ValueError("Received non‑positive coefficient during balancing")

    return tuple(lhs_coeffs), tuple(rhs_coeffs)
+
*** End File