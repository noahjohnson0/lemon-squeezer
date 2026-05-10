import sympy
from math import gcd
from functools import reduce

def parse_formula(formula: str) -> dict[str, int]:
    elements = {}
    stack = []
    current_element = ''
    current_count = 0
    multiplier = 1
    i = 0
    while i < len(formula):
        char = formula[i]
        if char.isupper():
            if current_element:
                elements[current_element] = elements.get(current_element, 0) + current_count * multiplier
                current_element = ''
                current_count = 0
                multiplier = 1
            current_element += char
        elif char.islower():
            current_element += char
        elif char.isdigit():
            current_count = int(char)
            j = i + 1
            while j < len(formula) and formula[j].isdigit():
                current_count = current_count * 10 + int(formula[j])
                j += 1
            i = j - 1
        elif char == '(':
            stack.append(multiplier)
            multiplier = 1
        elif char == ')':
            if stack:
                multiplier = stack.pop()
            else:
                raise ValueError("Unmatched parenthesis")
        i += 1
    if current_element:
        elements[current_element] = elements.get(current_element, 0) + current_count * multiplier
    return elements

def balance(equation: str) -> tuple[list[int], list[int]]:
    left_part, right_part = equation.split('->')
    left_compounds = left_part.strip().split('+')
    right_compounds = right_part.strip().split('+')

    left_elements = []
    for compound in left_compounds:
        left_elements.append(parse_formula(compound))
    right_elements = []
    for compound in right_compounds:
        right_elements.append(parse_formula(compound))

    all_elements = set()
    for comp in left_elements + right_elements:
        all_elements.update(comp.keys())
    elements_list = list(all_elements)

    num_elements = len(elements_list)
    num_compounds = len(left_compounds) + len(right_compounds)
    A = []
    for element in elements_list:
        row = []
        for i, comp in enumerate(left_compounds + right_compounds):
            count = comp.get(element, 0)
            if i < len(left_compounds):
                row.append(count)
            else:
                row.append(-count)
        A.append(row)

    A_matrix = sympy.Matrix(A)
    null_space = A_matrix.nullspace()
    if not null_space:
        raise ValueError("Unbalanceable equation")

    solution = null_space[0]
    coefficients = [sympy.Rational(sol) for sol in solution]

    # Find LCM of denominators
    denominators = [coeff.denominator for coeff in coefficients]
    lcm = sympy.lcm(*denominators)
    coefficients = [coeff * lcm for coeff in coefficients]

    # Convert to integers
    coefficients = [int(coeff) for coeff in coefficients]

    left_coefficients = coefficients[:len(left_compounds)]
    right_coefficients = coefficients[len(left_compounds):]

    # Find GCD of all coefficients
    def find_gcd(list_numbers):
        return reduce(gcd, list_numbers)

    all_coefficients = left_coefficients + right_coefficients
    common_gcd = find_gcd(all_coefficients)
    if common_gcd != 0:
        left_coefficients = [c // common_gcd for c in left_coefficients]
        right_coefficients = [c // common_gcd for c in right_coefficients]

    if any(c <= 0 for c in left_coefficients + right_coefficients):
        raise ValueError("Unbalanceable equation")

    return (left_coefficients, right_coefficients)
