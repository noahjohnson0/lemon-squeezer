#!/usr/bin/env python3
"""
Simple unit conversion script.

Usage:  python3 convert.py "<value> <unit> ... to <target>"
"

import sys

# Mapping of unit identifiers to (canonical name, category, conversion factor)
# For non‑temperature units factor is from the base unit of the category.
# The base unit for each category is:
#  - Distance: m, factor 1.
#  - Mass:   g, factor 1.
#  - Time:   s, factor 1.
#  - Speed:  m/s, factor 1.
#  - Temperature: c, temperature units handled separately.
UNIT_INFO = {
    # Distance
    "mm": ("mm", "distance", 0.001),   # 1 mm = 0.001 m
    "cm": ("cm", "distance", 0.01),    # 1 cm = 0.01 m
    "m":  ("m",  "distance", 1.0),     # 1 m  = 1 m
    "km": ("km", "distance", 1000.0),  # 1 km = 1000 m
    # Mass
    "g":  ("g",  "mass", 1),           # 1 g  = 1 g
    "kg": ("kg", "mass", 1000),        # 1 kg = 1000 g
    # Time
    "s":  ("s",  "time", 1),           # 1 s  = 1 s
    "min": ("min", "time", 60),        # 1 min = 60 s
    "h":  ("h",  "time", 3600),        # 1 h  = 3600 s
    # Speed
    "m/s": ("m/s", "speed", 1),        # 1 m/s = 1 m/s
    "mph": ("mph", "speed", 0.44704),  # 1 mph = 0.44704 m/s
    "kph": ("kph", "speed", 0.277778),# 1 kph = 0.277778 m/s
    # Temperature
    "c":  ("c",  "temp", None),
    "f":  ("f",  "temp", None),
    "k":  ("k",  "temp", None),
}

# Alias mapping: map user friendly identifiers to canonical keys
# Only include aliases that already exist in UNIT_INFO
UNIT_ALIASES = {
    "m/s": "m/s",  # meters per second expressed as m/s
    "mm": "mm",
    "cm": "cm",
    "m":  "m",
    "km": "km",
    "g":  "g",
    "kg": "kg",
    "s":  "s",
    "min": "min",
    "h":  "h",
    "mph": "mph",
    "kph": "kph",
    "f":  "f",
    "c":  "c",
    "k":  "k",
}

# Ensure alias keys reference valid UNIT_INFO entries
for alias, key in list(UNIT_ALIASES.items()):
    if key not in UNIT_INFO:
        del UNIT_ALIASES[alias]


def normalize_unit(unit: str) -> str:
    """Return canonical key for a unit token."""
    return UNIT_ALIASES.get(unit.lower(), unit.lower())


def parse_expression(expr: str):
    """Parse <value> <unit> ... to <target> expression.
    Returns list of (value, unit) tuples and target unit string.
    """
    parts = expr.strip().split()
    if 'to' not in parts:
        sys.stderr.write("missing 'to' keyword\n")
        sys.exit(1)
    to_index = parts.index('to')
    before = parts[:to_index]
    target = parts[to_index+1:]
    if len(target) != 1:
        sys.stderr.write("target unit expected\n")
        sys.exit(1)
    target_unit = target[0]
    if len(before) < 2 or len(before) % 2 != 0:
        sys.stderr.write("invalid source terms\n")
        sys.exit(1)
    terms = []
    for i in range(0, len(before), 2):
        try:
            value = float(before[i])
        except ValueError:
            sys.stderr.write(f"invalid value: {before[i]}\n")
            sys.exit(1)
        unit = before[i+1]
        terms.append((value, unit))
    return terms, target_unit


def convert_temperature(value: float, src_unit: str, tgt_unit: str) -> float:
    """Handle temperature conversions: f <-> c <-> k."""
    src_key = normalize_unit(src_unit)
    tgt_key = normalize_unit(tgt_unit)
    # convert src to Celsius
    if src_key == 'c':
        c = value
    elif src_key == 'f':
        c = (value - 32) * 5/9
    elif src_key == 'k':
        c = value - 273.15
    else:
        sys.stderr.write(f"unknown temperature unit: {src_unit}\n")
        sys.exit(1)
    # Celsius to target
    if tgt_key == 'c':
        return c
    elif tgt_key == 'f':
        return c * 9/5 + 32
    elif tgt_key == 'k':
        return c + 273.15
    else:
        sys.stderr.write(f"unknown temperature unit: {tgt_unit}\n")
        sys.exit(1)


def main():
    if len(sys.argv) != 2:
        sys.stderr.write("usage: python3 convert.py \"<expr>\"\n")
        sys.exit(1)

    expr = sys.argv[1]
    terms, target_unit = parse_expression(expr)
    tgt_key = normalize_unit(target_unit)
    if tgt_key not in UNIT_INFO:
        sys.stderr.write("unknown target unit\n")
        sys.exit(1)
    tgt_cat = UNIT_INFO[tgt_key][1]

    # Temperature conversion
    if tgt_cat == 'temp':
        if len(terms) != 1:
            sys.stderr.write("temperature conversion requires a single value unit pair\n")
            sys.exit(1)
        value, src_unit = terms[0]
        value = convert_temperature(value, src_unit, target_unit)
        canon = UNIT_INFO[tgt_key][0]
        print(f"{value:.4f} {canon}")
        return

    # Non‑temperature targets
    total = 0.0
    cat_set = set()
    for value, unit in terms:
        u_key = normalize_unit(unit)
        if u_key not in UNIT_INFO:
            sys.stderr.write(f"unknown unit: {unit}\n")
            sys.exit(1)
        c = UNIT_INFO[u_key][1]
        if c == 'temp':
            sys.stderr.write("source term uses temperature unit with non‑temp target\n")
            sys.exit(1)
        cat_set.add(c)
        total += value * UNIT_INFO[u_key][2]
    if len(cat_set) != 1:
        sys.stderr.write("incompatible units\n")
        sys.exit(1)
    target_factor = UNIT_INFO[tgt_key][2]
    result = total / target_factor
    canon = UNIT_INFO[tgt_key][0]
    print(f"{result:.4f} {canon}")

if __name__ == "__main__":
    main()
