#!/usr/bin/env python3
import sys

# Unit classification
UNIT_CLASSES = {
    # Length
    'mm': 'length', 'cm': 'length', 'm': 'length', 'km': 'length',
    'in': 'length', 'ft': 'length', 'yd': 'length', 'mi': 'length',
    'mile': 'length', 'miles': 'length',
    # Mass
    'mg': 'mass', 'g': 'mass', 'kg': 'mass', 'oz': 'mass',
    'lb': 'mass', 'lbs': 'mass',
    # Volume
    'ml': 'volume', 'l': 'volume', 'gal': 'volume',
    # Temperature
    'c': 'temperature', 'f': 'temperature', 'k': 'temperature',
    # Speed
    'mph': 'speed', 'kph': 'speed', 'm/s': 'speed',
}

# Conversion factors to base units
LENGTH_FACTORS = {
    'mm': 0.001, 'cm': 0.01, 'm': 1.0, 'km': 1000.0,
    'in': 0.0254, 'ft': 0.3048, 'yd': 0.9144, 'mi': 1609.344,
    'mile': 1609.344, 'miles': 1609.344,
}
MASS_FACTORS = {
    'mg': 1e-6, 'g': 0.001, 'kg': 1.0,
    'oz': 0.028349523125,
    'lb': 0.45359237, 'lbs': 0.45359237,
}
VOLUME_FACTORS = {
    'ml': 0.001, 'l': 1.0, 'gal': 3.785411784,
}
SPEED_FACTORS = {
    'mph': 0.44704, 'kph': 0.2777777777777778, 'm/s': 1.0,
}

def convert_temp(value, from_unit, to_unit):
    """Convert a single temperature value."""
    if from_unit == to_unit:
        return value
    # Convert to Celsius first
    if from_unit == 'c':
        c = value
    elif from_unit == 'f':
        c = (value - 32.0) * 5.0 / 9.0
    elif from_unit == 'k':
        c = value - 273.15
    else:
        raise ValueError(f"unknown temperature unit '{from_unit}'")
    # Convert from Celsius to target
    if to_unit == 'c':
        return c
    elif to_unit == 'f':
        return c * 9.0 / 5.0 + 32.0
    elif to_unit == 'k':
        return c + 273.15
    else:
        raise ValueError(f"unknown temperature unit '{to_unit}'")

def error(message):
    sys.stderr.write(f"error: {message}\n")
    sys.exit(1)

def main():
    if len(sys.argv) < 2:
        error("no expression provided")
    expr = sys.argv[1]
    tokens = expr.split()
    # Find 'to'
    to_index = None
    for i, tok in enumerate(tokens):
        if tok.lower() == 'to':
            to_index = i
            break
    if to_index is None or to_index == 0 or to_index == len(tokens) - 1:
        error("invalid expression format")
    source_tokens = tokens[:to_index]
    target_token = tokens[to_index + 1]
    target_unit = target_token.lower()
    target_class = UNIT_CLASSES.get(target_unit)
    if target_class is None:
        error(f"unknown unit '{target_token}'")
    # Parse source terms
    if len(source_tokens) % 2 != 0:
        error("source terms must be value-unit pairs")
    source_class = None
    sum_base = 0.0
    temp_value = None
    temp_unit = None
    for i in range(0, len(source_tokens), 2):
        val_str = source_tokens[i]
        unit_str = source_tokens[i + 1]
        try:
            val = float(val_str)
        except ValueError:
            error(f"invalid number '{val_str}'")
        unit = unit_str.lower()
        unit_cls = UNIT_CLASSES.get(unit)
        if unit_cls is None:
            error(f"unknown unit '{unit_str}'")
        if source_class is None:
            source_class = unit_cls
        elif source_class != unit_cls:
            error("incompatible units")
        # Handle temperature separately
        if unit_cls == 'temperature':
            if temp_value is not None:
                error("multiple temperature terms")
            temp_value = val
            temp_unit = unit
            continue
        # Get factor to base unit
        if unit_cls == 'length':
            factor = LENGTH_FACTORS[unit]
        elif unit_cls == 'mass':
            factor = MASS_FACTORS[unit]
        elif unit_cls == 'volume':
            factor = VOLUME_FACTORS[unit]
        elif unit_cls == 'speed':
            factor = SPEED_FACTORS[unit]
        else:
            error(f"unknown unit class for '{unit_str}'")
        sum_base += val * factor
    # After parsing, perform conversion
    if source_class == 'temperature':
        if target_class != 'temperature':
            error("incompatible units")
        result = convert_temp(temp_value, temp_unit, target_unit)
    else:
        if target_class != source_class:
            error("incompatible units")
        # Get target factor
        if target_class == 'length':
            target_factor = LENGTH_FACTORS[target_unit]
        elif target_class == 'mass':
            target_factor = MASS_FACTORS[target_unit]
        elif target_class == 'volume':
            target_factor = VOLUME_FACTORS[target_unit]
        elif target_class == 'speed':
            target_factor = SPEED_FACTORS[target_unit]
        else:
            error(f"unknown target unit class for '{target_token}'")
        result = sum_base / target_factor
    # Output
    print(f"{result:.4f} {target_unit}")

if __name__ == "__main__":
    main()
