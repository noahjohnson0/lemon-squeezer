#!/usr/bin/env python3
"""Command line unit converter.

Usage:
    python3 convert.py "<value> <unit> [<value> <unit> …] to <target_unit>"

Supported units (case‑insensitive):
    Length:  mm, cm, m, km, in, ft, yd, mi (or mile/miles)
    Mass:   mg, g, kg, oz, lb (or lbs)
    Volume: ml, l, gal (US gallon = 3.785411784 L)
    Temperature: c, f, k (single value only)
    Speed:  mph, kph, m/s

The result is printed to 4 decimal places followed by a space and the
canonical target unit name (e.g. '170.1800 cm').

Any error results in exit status 1 and an error message written to
stderr, e.g. 'error: incompatible units'.
"""

import sys
import math
from typing import Dict, Tuple, List

# ---------------------------------------------------------------------------
# Canonical unit names and aliases
# ---------------------------------------------------------------------------
# For each supported unit we store
#   * a canonical name used for output
#   * the category (length, mass, volume, temp, speed)
#   * conversion factor to the base unit (see comment for each category)
#
# Temperature is handled separately because conversion is not linear.

# Base units: meter, gram, liter, kelvin, meter per second
_CATEGORY_BASE_FACTORS = {
    "length": 1.0,  # meter
    "mass": 1.0,    # gram
    "volume": 1.0,  # liter
    "temp": 1.0,    # kelvin (not used directly)
    "speed": 1.0,   # m/s
}

UNIT_INFO: Dict[str, Tuple[str, str, float]] = {
    # Length (base in meters)
    "mm": ("mm", "length", 0.001),
    "cm": ("cm", "length", 0.01),
    "m": ("m", "length", 1.0),
    "km": ("km", "length", 1000.0),
    "in": ("in", "length", 0.0254),
    "ft": ("ft", "length", 0.3048),
    "yd": ("yd", "length", 0.9144),
    "mi": ("mi", "length", 1609.344),
    # Mass (base in grams)
    "mg": ("mg", "mass", 0.001),
    "g": ("g", "mass", 1.0),
    "kg": ("kg", "mass", 1000.0),
    "oz": ("oz", "mass", 28.349523125),
    "lb": ("lb", "mass", 453.59237),
    # Volume (base in liters)
    "ml": ("ml", "volume", 0.001),
    "l": ("l", "volume", 1.0),
    "gal": ("gal", "volume", 3.785411784),
    # Speed (base in m/s)
    "mph": ("mph", "speed", 0.44704),
    "kph": ("kph", "speed", 0.2777777777777778),
    "m/s": ("m/s", "speed", 1.0),
    # Temperature units handled specially
    "c": ("c", "temp", 0.0),
    "f": ("f", "temp", 0.0),
    "k": ("k", "temp", 0.0),
}

# Aliases (lowercase -> canonical key)
UNIT_ALIASES: Dict[str, str] = {
    # Length aliases
    "mile": "mi",
    "miles": "mi",
    # Mass aliases
    "lbs": "lb",
    # Volume aliases (none beyond base)
    # Speed aliases (none beyond base)
    # Temperature aliases (none)
}

# Merge aliases into UNIT_INFO mapping, but we keep UNIT_INFO unchanged for
# canonical lookup. UNIT_ALIASES only tells us which canonical key the alias
# refers to.

# ---------------------------------------------------------------------------
# Conversion helpers
# ---------------------------------------------------------------------------

def to_base(value: float, unit: str) -> float:
    """Convert value from the given unit to its category base unit."""
    key = unit.lower()
    if key in UNIT_ALIASES:
        key = UNIT_ALIASES[key]
    if key not in UNIT_INFO:
        return math.nan
    _, category, factor = UNIT_INFO[key]
    if category == "temp":
        return math.nan  # handled elsewhere
    return value * factor


def from_base(value: float, target_unit: str) -> float:
    """Convert value from base unit to the target unit."""
    key = target_unit.lower()
    if key in UNIT_ALIASES:
        key = UNIT_ALIASES[key]
    if key not in UNIT_INFO:
        return math.nan
    _, category, factor = UNIT_INFO[key]
    if category == "temp":
        return math.nan
    return value / factor

# Temperature conversion

def convert_temperature(value: float, src_unit: str, tgt_unit: str) -> float:
    src = src_unit.lower()
    tgt = tgt_unit.lower()
    if src in UNIT_ALIASES:
        src = UNIT_ALIASES[src]
    if tgt in UNIT_ALIASES:
        tgt = UNIT_ALIASES[tgt]
    if src not in UNIT_INFO or tgt not in UNIT_INFO:
        raise ValueError("unknown temperature unit")
    # source -> Celsius
    if src == "c":
        c = value
    elif src == "f":
        c = (value - 32.0) * 5.0 / 9.0
    elif src == "k":
        c = value - 273.15
    else:
        raise ValueError("unknown temperature unit")
    # Celsius -> target
    if tgt == "c":
        return c
    elif tgt == "f":
        return c * 9.0 / 5.0 + 32.0
    elif tgt == "k":
        return c + 273.15
    else:
        raise ValueError("unknown temperature unit")

# ---------------------------------------------------------------------------
# Argument parsing and conversion logic
# ---------------------------------------------------------------------------

def error(message: str):
    sys.stderr.write(f"error: {message}\n")
    sys.exit(1)


def parse_expression(expr: str) -> Tuple[List[Tuple[float, str]], str]:
    """Parse the conversion expression.

    Returns: (list of (value, unit)), target_unit
    """
    # split on 'to' (case‑insensitive)
    parts = expr.strip().split()
    if not parts:
        error("empty expression")
    try:
        to_index = next(i for i, token in enumerate(parts) if token.lower() == "to")
    except StopIteration:
        error("missing 'to' keyword")
    # before to: source terms
    source_parts = parts[:to_index]
    target_parts = parts[to_index + 1 :]
    if not target_parts:
        error("missing target unit")
    if len(target_parts) > 1:
        error("invalid target unit")
    target_unit = target_parts[0]
    # parse source terms in pairs
    if len(source_parts) % 2 != 0:
        error("source terms must be in value unit pairs")
    terms: List[Tuple[float, str]] = []
    for i in range(0, len(source_parts), 2):
        val_str = source_parts[i]
        unit_str = source_parts[i + 1]
        try:
            val = float(val_str)
        except ValueError:
            error(f"invalid number: {val_str}")
        terms.append((val, unit_str))
    return terms, target_unit


def main():
    if len(sys.argv) != 2:
        sys.stderr.write("usage: python3 convert.py \"<expression>\"\n")
        sys.exit(1)
    expr = sys.argv[1]
    terms, target_unit = parse_expression(expr)
    # Determine category of target unit
    tgt_key = target_unit.lower()
    if tgt_key in UNIT_ALIASES:
        tgt_key = UNIT_ALIASES[tgt_key]
    if tgt_key not in UNIT_INFO:
        error("unknown target unit")
    tgt_category = UNIT_INFO[tgt_key][1]
    # Handle temperature separately
    if tgt_category == "temp":
        # Must be exactly one source term
        if len(terms) != 1:
            error("temperature conversion requires a single value unit pair")
        src_unit = terms[0][1]
        src_val = terms[0][0]
        try:
            result = convert_temperature(src_val, src_unit, target_unit)
        except ValueError as e:
            error(str(e))
        print(f"{result:.4f} {UNIT_INFO[UNIT_ALIASES.get(target_unit.lower(), target_unit.lower())][0]}")
        return
    # For non‑temperature units, collect category and sum values
    category_set = set()
    total_base = 0.0
    for val, unit in terms:
        # Resolve alias
        unit_key = unit.lower()
        if unit_key in UNIT_ALIASES:
            unit_key = UNIT_ALIASES[unit_key]
        if unit_key not in UNIT_INFO:
            error(f"unknown unit: {unit}")
        _, cat, _ = UNIT_INFO[unit_key]
        if cat == "temp":
            error("temperature conversion must use 'temp' units"")
        category_set.add(cat)
        base_val = to_base(val, unit)
        if math.isnan(base_val):
            error(f"unknown unit: {unit}")
        total_base += base_val
    if len(category_set) != 1:
        error("incompatible units")
    category = next(iter(category_set))
    # convert total_base to target unit
    if category == "temp":
        error("logic error: temp category reached for non‑temp")
    if category == "speed":
        # Ensure both source and target are speed units
        if to_index := None:
            pass  # placeholder
    # Actually perform conversion
    result_val: float
    try:
        result_val = from_base(total_base, target_unit)
        if math.isnan(result_val):
            # If conversion factor missing, might be because target alias
            result_val = from_base(total_base, target_unit)
        # For safety, check for NaN
        if math.isnan(result_val):
            error("unknown unit in conversion")
    except Exception:
        error("conversion error")
    # Format output
    canonical_tgt = UNIT_INFO[UNIT_ALIASES.get(target_unit.lower(), target_unit.lower())][0]
    print(f"{result_val:.4f} {canonical_tgt}")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.stderr.write(
            "usage: python3 convert.py \"<value> <unit> ... to <target_unit>\"\n"
        )
        sys.exit(1)
    expression = sys.argv[1]
    try:
        parse_expression(expression)
    except SystemExit:
        # error() already handled exit
        pass
