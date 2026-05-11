#!/usr/bin/env python3
"""
Household bleach water purification dose calculator.

This module implements the CDC emergency-disinfection guidance for
purifying water with standard household bleach.

Author: OpenAI ChatGPT
"""

import math
from typing import Dict, Optional


def bleach_drops(
    volume_liters: float,
    clarity: str = "clear",
    concentration_pct: float = 5.0,
) -> Dict[str, object]:
    """
    Return a dictionary with the recommended bleach dose for purifying water.

    Parameters
    ----------
    volume_liters : float
        Volume of water to purify, in liters. Must be > 0.
    clarity : str, optional
        Water clarity. Must be either "clear" or "cloudy".
        "cloudy" doubles the dose compared to clear water.
    concentration_pct : float, optional
        Bleach concentration in percent (5–9% is normal).
        Values outside 1–12% are rejected. Values outside 5–9% generate a warning.

    Returns
    -------
    dict
        Dictionary containing:
            - 'drops' (int): number of drops to add (rounded up).
            - 'ml' (float): total milliliters of bleach.
            - 'wait_minutes' (int): recommended waiting time (>= 30).
            - 'warning' (str, optional): warning message if concentration_pct is
              outside the normal 5–9% range.

    Raises
    ------
    ValueError
        If volume_liters <= 0, clarity not in {"clear", "cloudy"},
        or concentration_pct < 1 or > 12.
    """
    # Validate inputs
    if volume_liters <= 0:
        raise ValueError("volume_liters must be greater than 0.")
    if clarity not in {"clear", "cloudy"}:
        raise ValueError('clarity must be either "clear" or "cloudy".')
    if concentration_pct < 1 or concentration_pct > 12:
        raise ValueError("concentration_pct must be between 1 and 12 (inclusive).")

    # Determine drops per liter
    drops_per_liter = 2.0  # base dose for clear water
    if clarity == "cloudy":
        drops_per_liter *= 2  # double dose for cloudy water

    # Compute raw drop count and round up
    raw_drops = volume_liters * drops_per_liter
    drops = math.ceil(raw_drops)

    # Convert drops to milliliters (1 drop ≈ 0.05 mL)
    ml = drops * 0.05

    # Minimum wait time
    wait_minutes = 30

    # Prepare result dictionary
    result: Dict[str, object] = {
        "drops": drops,
        "ml": ml,
        "wait_minutes": wait_minutes,
    }

    # Add warning if concentration_pct is outside normal 5–9% range
    if concentration_pct < 5 or concentration_pct > 9:
        result["warning"] = (
            f"Bleach concentration {concentration_pct:.1f}% is outside the "
            "recommended 5–9% range. Use with caution."
        )

    return result
