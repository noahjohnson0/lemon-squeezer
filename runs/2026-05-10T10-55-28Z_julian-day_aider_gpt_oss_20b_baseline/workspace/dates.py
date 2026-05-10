"""
Utility functions for astronomical date calculations.

Functions
---------
easter(year: int) -> tuple[int, int, int]
    Compute the date of Western (Gregorian) Easter for the given year
    using the Anonymous Gregorian / Meeus-Jones-Butcher algorithm.
    Returns a tuple (year, month, day). Raises ValueError for years
    before 1583.

julian_day(year: int, month: int, day: int, hour: float = 0.0) -> float
    Compute the Julian Day Number for a UTC instant on the proleptic
    Gregorian calendar.  The hour argument is a decimal hour
    (e.g. 12.0 for noon).  Returns a float JD.
"""

from __future__ import annotations
import math

__all__ = ["easter", "julian_day"]


def easter(year: int) -> tuple[int, int, int]:
    """
    Western (Gregorian) Easter date via the Anonymous Gregorian /
    Meeus-Jones-Butcher algorithm.

    Parameters
    ----------
    year : int
        The year for which to compute Easter. Must be >= 1583.

    Returns
    -------
    tuple[int, int, int]
        (year, month, day) of Easter.

    Raises
    ------
    ValueError
        If year < 1583.
    """
    if year < 1583:
        raise ValueError("Easter calculation is only valid for years >= 1583")

    a = year % 19
    b = year // 100
    c = year % 100
    d = b // 4
    e = b % 4
    f = (b + 8) // 25
    g = (b - f + 1) // 3
    h = (19 * a + b - d - g + 15) % 30
    i = c // 4
    k = c % 4
    l = (32 + 2 * e + 2 * i - h - k) % 7
    m = (a + 11 * h + 22 * l) // 451
    month = (h + l - 7 * m + 114) // 31
    day = ((h + l - 7 * m + 114) % 31) + 1

    return (year, month, day)


def julian_day(year: int, month: int, day: int, hour: float = 0.0) -> float:
    """
    Julian Day Number for a UTC instant on the proleptic Gregorian calendar.

    Parameters
    ----------
    year : int
        Gregorian year.
    month : int
        Gregorian month (1-12).
    day : int
        Gregorian day of month.
    hour : float, optional
        Decimal hour of the day (e.g., 12.0 for noon). Default is 0.0.

    Returns
    -------
    float
        Julian Day Number (JD) for the specified instant.
    """
    # Adjust month and year for the algorithm
    if month <= 2:
        Y = year - 1
        M = month + 12
    else:
        Y = year
        M = month

    # Compute the components
    A = Y // 100
    B = 2 - A + (A // 4)

    # Julian Day Number calculation
    jd = (
        math.floor(365.25 * (Y + 4716))
        + math.floor(30.6001 * (M + 1))
        + day
        + B
        - 1524.5
    )

    # Add fractional day from hour
    jd += hour / 24.0

    return jd
