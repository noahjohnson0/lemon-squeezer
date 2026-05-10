import sys
import re

# Conversion factors for length units
length_conversion = {
    'mm': 0.1,
    'cm': 1.0,
    'm': 100.0,
    'km': 100000.0,
    'in': 2.54,
    'ft': 30.48,
    'yd': 91.44,
    'mi': 160934.0
}

# Conversion factors for mass units
mass_conversion = {
    'mg': 0.001,
    'g': 1.0,
    'kg': 1000.0,
    'oz': 28.3495,
    'lb': 453.592
}

# Conversion factors for volume units
volume_conversion = {
    'ml': 1.0,
    'l': 1000.0,
    'gal': 3785.411784
}

# Conversion factors for temperature units
temperature_conversion = {
    'c': lambda x: x,
    'f': lambda x: (x - 32) * 5/9,
    'k': lambda x: x - 273.15
}

# Conversion factors for speed units
speed_conversion = {
    'mph': 1.0,
    'kph': 1.60934,
    'm/s': 3.6
}

def convert_units(value, unit, target_unit):
    if unit in length_conversion:
        base_value = value * length_conversion[unit]
        return base_value / length_conversion[target_unit]

    elif unit in mass_conversion:
        base_value = value * mass_conversion[unit]
        return base_value / mass_conversion[target_unit]

    elif unit in volume_conversion:
        base_value = value * volume_conversion[unit]
        return base_value / volume_conversion[target_unit]

    elif unit in temperature_conversion:
        if target_unit not in temperature_conversion:
            print(f"error: unknown unit '{target_unit}'", file=sys.stderr)
            sys.exit(1)

        return temperature_conversion[target_unit](temperature_conversion[unit](value))

    elif unit in speed_conversion:
        base_value = value * speed_conversion[unit]
        return base_value / speed_conversion[target_unit]

    else:
        print(f"error: unknown unit '{unit}'", file=sys.stderr)
        sys.exit(1)

def parse_expression(expression):
    # Split the expression into parts
    parts = re.split(r'(\s+to\s+)', expression.strip())
    if len(parts) != 2:
        print(f"error: invalid expression '{expression}'", file=sys.stderr)
        sys.exit(1)

    values_units, target_unit = parts

    # Parse the values and units
    value_units_pairs = re.findall(r'(\d+[\.\d]*)\s*([a-zA-Z]+)', values_units)
    if not value_units_pairs:
        print(f"error: invalid expression '{expression}'", file=sys.stderr)
        sys.exit(1)

    # Check for temperature conversion
    if any(unit.lower() in ['c', 'f', 'k'] for _, unit in value_units_pairs):
        if len(value_units_pairs) > 1:
            print(f"error: multi-term temperature inputs are not supported", file=sys.stderr)
            sys.exit(1)

        value, unit = value_units_pairs[0]
        return convert_units(float(value), unit.lower(), target_unit.strip().lower())

    # Sum the values within compatible units
    total_value = 0.0
    for value, unit in value_units_pairs:
        if unit.lower() not in length_conversion and \
           unit.lower() not in mass_conversion and \
           unit.lower() not in volume_conversion and \
           unit.lower() not in speed_conversion:
            print(f"error: unknown unit '{unit}'", file=sys.stderr)
            sys.exit(1)

        total_value += float(value) * (length_conversion.get(unit.lower(), 0) or
                                       mass_conversion.get(unit.lower(), 0) or
                                       volume_conversion.get(unit.lower(), 0) or
                                       speed_conversion.get(unit.lower(), 0))

    # Convert to the target unit
    return convert_units(total_value, value_units_pairs[0][1].lower(), target_unit.strip().lower())

def main():
    if len(sys.argv) != 2:
        print(f"error: invalid number of arguments", file=sys.stderr)
        sys.exit(1)

    expression = sys.argv[1]
    result = parse_expression(expression)
    print(f"{result:.4f} {expression.split('to')[1].strip()}")

if __name__ == '__main__':
    main()
