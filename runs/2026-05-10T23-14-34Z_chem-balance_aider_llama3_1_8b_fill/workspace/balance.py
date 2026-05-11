import re
from collections import defaultdict
import numpy as np
import math  # Add this line to import the math module

def parse_formula(formula: str) -> int:
    """
    Parse a formula string and return the total count of elements.
    
    Example:
        parse_formula("H2O") returns 3
        parse_formula("Al2(SO4)3") returns 13
    """
    count = 1
    for element in re.findall(r'[A-Z][a-z]*\d*', formula):
        if '(' in element and ')' in element:
            group = element[element.index('('):element.index(')')+1]
            sub_count, sub_formula = re.match(r'(\d*)\(([^)]+)\)', group).groups()
            if sub_count == '':
                sub_count = 1
            else:
                sub_count = int(sub_count)
            count *= parse_formula(sub_formula)
        else:
            count *= int(element[:-1]) if element[-1].isdigit() else 1
    return count

def balance(equation: str) -> tuple[list[int], list[int]]:
    """
    Take an unbalanced equation string like "H2 + O2 -> H2O".
    Return (lhs_coefficients, rhs_coefficients) as lists of POSITIVE integers
    in the smallest-integer form.

    Example:
        balance("H2 + O2 -> H2O") returns ([2, 1], [2])
        balance("CH4 + O2 -> CO2 + H2O") returns ([1, 2], [1, 2])
    """
    lhs, rhs = equation.split('->')
    lhs_reactants = re.findall(r'([A-Z][a-z]*\d*)|(\([^)]+\))', lhs)
    rhs_products = re.findall(r'([A-Z][a-z]*\d*)|(\([^)]+\))', rhs)

    # Parse element counts
    lhs_counts = defaultdict(int)
    for reactant in lhs_reactants:
        if '(' in reactant and ')' in reactant:
            group = reactant[reactant.index('('):reactant.index(')')+1]
            count, formula = re.match(r'(\d*)\(([^)]+)\)', group).groups()
            if count == '':
                count = 1
            else:
                count = int(count)
            for element in re.findall(r'[A-Z][a-z]*', formula):
                lhs_counts[element] += count * parse_formula(formula)
        else:
            lhs_counts[reactant] += 1

    rhs_counts = defaultdict(int)
    for product in rhs_products:
        if '(' in product and ')' in product:
            group = product[product.index('('):product.index(')')+1]
            count, formula = re.match(r'(\d*)\(([^)]+)\)', group).groups()
            if count == '':
                count = 1
            else:
                count = int(count)
            for element in re.findall(r'[A-Z][a-z]*', formula):
                rhs_counts[element] += count * parse_formula(formula)
        else:
            rhs_counts[product] += 1

    # Build the element-count matrix
    A = np.zeros((len(lhs_counts), len(rhs_counts)))
    elements = list(lhs_counts.keys()) + list(rhs_counts.keys())
    for i, (element, lhs_count) in enumerate(lhs_counts.items()):
        j = list(rhs_counts.keys()).index(element)
        A[i, j] += lhs_count
    for i, element in enumerate(lhs_counts):
        if element not in rhs_counts:
            A[i, len(rhs_counts)] -= lhs_counts[element]

    # Solve the balancing as a linear-algebra problem
    null_vector = np.linalg.lstsq(A, np.zeros(len(rhs_counts)), rcond=None)[0]
    coefficients = np.round(null_vector).astype(int)
    if not all(coefficients > 0):
        raise ValueError("Unbalanceable input")

    # Reduce coefficients to smallest positive integers
    lhs_coefficients = []
    for i in range(len(lhs_counts)):
        coefficient = math.gcd(lhs_counts[list(lhs_counts.keys())[i]], coefficients[i])
        lhs_coefficients.append(coefficient // math.gcd(coefficient, coefficients[i]))

    return (lhs_coefficients, np.round(coefficients).astype(int))
