from typing import List, Tuple
import re
import sympy as sp

def parse_formula(formula: str) -> dict:
    """Parse a chemical formula into an element count dictionary."""
    elements = {}
    i = 0
    while i < len(formula):
        if formula[i].isalpha():
            # Element symbol (1 or 2 letters)
            elem = formula[i]
            i += 1
            if i < len(formula) and formula[i].isupper():
                elem += formula[i]
                i += 1

            # Count of this element in the current group
            count = ''
            while i < len(formula) and formula[i].isdigit():
                count += formula[i]
                i += 1
            if not count:
                count = '1'
            elements[elem] = elements.get(elem, 0) + int(count)

        elif formula[i] == '(':
            # Parenthesized group
            depth = 1
            j = i + 1
            while j < len(formula):
                if formula[j] == '(':
                    depth += 1
                elif formula[j] == ')':
                    depth -= 1
                    if depth == 0:
                        break
                j += 1

            # Parse the group and multiply by outer coefficient
            count = ''
            while j < len(formula) and formula[j].isdigit():
                count += formula[j]
                j += 1
            if not count:
                count = '1'
            subformula = parse_formula(formula[i+1:j])
            for elem, c in subformula.items():
                elements[elem] = elements.get(elem, 0) + int(count) * c

            i = j + 1

    return elements

def balance(equation: str) -> Tuple[List[int], List[int]]:
    """
    Take an unbalanced equation string like "H2 + O2 -> H2O".
    Return (lhs_coefficients, rhs_coefficients) as lists of POSITIVE integers
    in the smallest-integer form.

    Example:
        balance("H2 + O2 -> H2O") returns ([2, 1], [2])
        balance("CH4 + O2 -> CO2 + H2O") returns ([1, 2], [1, 2])
    """
    lhs_str, rhs_str = equation.split('->')
    lhs_formulas = lhs_str.split('+')
    rhs_formulas = rhs_str.split('+')

    # Parse formulas
    lhs_elements = {formula: parse_formula(formula) for formula in lhs_formulas}
    rhs_elements = {formula: parse_formula(formula) for formula in rhs_formulas}

    # Create element set and coefficient variables
    elements_set = set()
    for elem_counts in lhs_elements.values():
        elements_set.update(elem_counts.keys())
    for elem_counts in rhs_elements.values():
        elements_set.update(elem_counts.keys())

    n_lhs = len(lhs_formulas)
    n_rhs = len(rhs_formulas)

    # Create matrix A and vector b
    A = sp.zeros(len(elements_set) + 1, n_lhs + n_rhs)
    b = sp.Matrix([0] * (len(elements_set) + 1))

    # Fill in the matrix A with coefficients from formulas
    for i, formula in enumerate(lhs_formulas):
        elem_counts = lhs_elements[formula]
        for j, elem in enumerate(elements_set):
            if elem in elem_counts:
                A[j, i] = elem_counts[elem]

    for i, formula in enumerate(rhs_formulas):
        elem_counts = rhs_elements[formula]
        for j, elem in enumerate(elements_set):
            if elem in elem_counts:
                A[j, n_lhs + i] = -elem_counts[elem]

    # Add the constraint that coefficients must sum to 1
    A[-1, :] = [1] * (n_lhs + n_rhs)
    b[-1] = 0

    # Solve for null space of A
    null_space = sp.Matrix(A).nullspace()

    if not null_space:
        raise ValueError("Equation cannot be balanced")

    # Find the smallest positive integer solution
    coefficients = [int(sp.Rational(null_space[0][i]).limit_denominator()) for i in range(n_lhs + n_rhs)]
    gcd = sp.gcd(coefficients)
    coefficients = [coeff // gcd for coeff in coefficients]

    lhs_coefficients = coefficients[:n_lhs]
    rhs_coefficients = coefficients[n_lhs:]

    return (lhs_coefficients, rhs_coefficients)

if __name__ == "__main__":
    import sys
    if len(sys.argv) != 2:
        print("Usage: python balance.py 'equation'")
        sys.exit(1)
    
    equation = sys.argv[1]
    try:
        lhs_coeffs, rhs_coeffs = balance(equation)
        print(f"Left-hand side coefficients: {lhs_coeffs}")
        print(f"Right-hand side coefficients: {rhs_coeffs}")
    except ValueError as e:
        print(str(e))
