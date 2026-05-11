import sys

# Define unit mappings for normalization
unit_mapping = {
    'mi': ['mi', 'mile', 'miles'],
    'm': ['m'],
    'km': ['km'],
    'in': ['in'],
    'ft': ['ft'],
    'yd': ['yd'],
    'mg': ['mg'],
    'g': ['g'],
    'kg': ['kg'],
    'oz': ['oz'],
    'lb': ['lb', 'lbs'],
    'ml': ['ml'],
    'l': ['l'],
    'gal': ['gal'],
    'c': ['c'],
    'f': ['f'],
    'k': ['k'],
    'mph': ['mph'],
    'kph': ['kph'],
    'm/s': ['m/s'],
}

# Define unit categories
unit_categories = {
    'length': ['mm', 'cm', 'm', 'km', 'in', 'ft', 'yd', 'mi'],
    'mass': ['mg', 'g', 'kg', 'oz', 'lb'],
    'volume': ['ml', 'l', 'gal'],
    'temperature': ['c', 'f', 'k'],
    'speed': ['mph', 'kph', 'm/s'],
}

# Define conversion factors from unit to base unit
conversion_factors = {
    'length': {
        'mm': 0.001,
        'cm': 0.01,
        'm': 1,
        'km': 1000,
        'in': 0.0254,
        'ft': 0.3048,
        'yd': 0.9144,
        'mi': 1609.344,
    },
    'mass': {
        'mg': 0.001,
        'g': 0.001,
        'kg': 1,
        'oz': 0.0283495,
        'lb': 0.453592,
    },
    'volume': {
        'ml': 0.001,
        'l': 1,
        'gal': 3.785411784,
    },
    'speed': {
        'mph': 0.44704,
        'kph': 0.277778,
        'm/s': 1,
    },
}

# Normalize unit to standard key
def normalize_unit(unit):
    unit = unit.lower()
    for key, synonyms in unit_mapping.items():
        if unit in synonyms:
            return key
    return None

# Check if unit is valid
def is_valid_unit(unit):
    return normalize_unit(unit) is not None

# Get unit category
def get_unit_category(unit):
    for category, units in unit_categories.items():
        if unit in units:
            return category
    return None

# Convert value from unit to base unit
def convert_to_base_unit(value, unit, target_category):
    if target_category == 'temperature':
        if unit == 'c':
            return value
        elif unit == 'f':
            return (value - 32) * 5 / 9
        elif unit == 'k':
            return value - 273.15
        else:
            return 0
    else:
        factor = conversion_factors[target_category][unit]
        return value * factor

# Convert value from base unit to target unit
def convert_to_unit(value, target_unit, target_category):
    if target_category == 'temperature':
        if target_unit == 'c':
            return value
        elif target_unit == 'f':
            return (value * 9 / 5) + 32
        elif target_unit == 'k':
            return value + 273.15
        else:
            return 0
    else:
        factor = 1 / conversion_factors[target_category][target_unit]
        return value * factor

# Main function
def main():
    if len(sys.argv) != 2:
        print("error: missing expression")
        sys.exit(1)
    expr = sys.argv[1]

    parts = expr.split(' to ')
    if len(parts) != 2:
        print("error: invalid expression")
        sys.exit(1)
    terms_str, target_unit = parts
    terms = terms_str.split()

    if not is_valid_unit(target_unit):
        print(f"error: invalid target unit {target_unit}")
        sys.exit(1)

    parsed_terms = []
    for term in terms:
        if not term:
            print("error: invalid term")
            sys.exit(1)
        parts = term.split()
        if len(parts) != 2:
            print("error: invalid term")
            sys.exit(1)
        value_str, unit = parts
        try:
            value = float(value_str)
        except ValueError:
            print(f"error: invalid value {value_str}")
            sys.exit(1)
        normalized_unit = normalize_unit(unit)
        if normalized_unit is None:
            print(f"error: invalid unit {unit}")
            sys.exit(1)
        parsed_terms.append((value, normalized_unit))

    target_category = get_unit_category(target_unit)
    if target_category is None:
        print(f"error: invalid target unit {target_unit}")
        sys,exit(1)

    if target_category == 'temperature':
        if len(parsed_terms) != 1:
            print("error: temperature input must have one term")
            sys.exit(1)
        value, unit = parsed_terms[0]
        if unit not in ['c', 'f', 'k']:
            print(f"error: invalid temperature unit {unit}")
            sys.exit(1)
        # Convert to Celsius
        if unit == 'f':
            value = (value - 32) * 5 / 9
        elif unit == 'k':
            value = value - 273.15
        # Convert to target unit
        result = convert_to_unit(value, target_unit, target_category)
        print(f"{result:.4f} {target_unit}")
        return

    # Sum the values in their category's base unit
    total = 0.0
    for value, unit in parsed_terms:
        base_value = convert_to_base_unit(value, unit, target_category)
        total += base_value

    # Convert total to target unit
    result = convert_to_unit(total, target_unit, target_category)
    print(f"{result:.4f} {target_unit}")

if __name__ == "__main__":
    main()
