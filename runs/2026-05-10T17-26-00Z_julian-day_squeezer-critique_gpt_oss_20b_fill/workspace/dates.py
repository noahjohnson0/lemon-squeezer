"""Utilities for computing Easter dates and Julian Day numbers.

This module provides two functions:

- :func:`easter` – computes the Gregorian Easter date for a given year using the
  Anonymous Gregorian (Meeus–Jones–Butcher) algorithm.
- :func:`julian_day` – returns the Julian Day Number for an instant in UTC
  expressed in the proleptic Gregorian calendar.

The functions use only the Python standard library.
"""

from __future__ import annotations

import math

__all__ = ["easter", "julian_day"]


+def easter(year: int) -> tuple[int, int, int]:
+    """Return the Gregorian Easter date for *year*.
+
+    The algorithm implemented is the Anonymous Gregorian algorithm
+    (also known as the Meeus–Jones–Butcher algorithm).  It is valid for
+    years >= 1583, the year of adoption of the Gregorian calendar.
+
+    Parameters
+    ----------
+    year:
+        The year for which to compute Easter.  Must be >= 1583.
+
+    Returns
+    -------
+    tuple[int, int, int]
+        ``(year, month, day)`` describing the date of Easter Sunday.
+
+    Raises
+    ------
+    ValueError
+        If *year* is less than 1583.
+    """
+
+    if year < 1583:
+        raise ValueError("Easter calculation valid for year 1583 or later only.")
+
+    a = year % 19
+    b = year // 100
+    c = year % 100
+    d = b // 4
+    e = b % 4
+    f = (b + 8) // 25
+    g = (b - f + 1) // 3
+    h = (19 * a + b - d - g + 15) % 30
+    i = c // 4
+    k = c % 4
+    l = (32 + 2 * e + 2 * i - h - k) % 7
+    m = (a + 11 * h + 22 * l) // 451
+    month = (h + l - 7 * m + 114) // 31
+    day = ((h + l - 7 * m + 114) % 31) + 1
+
+    return year, month, day
+
+
+def julian_day(year: int, month: int, day: int, hour: float = 0.0) -> float:
+    """Return the Julian Day Number for a UTC instant on the proleptic Gregorian calendar.
+
+    Parameters
+    ----------
+    year, month, day:
+        Calendar date components.  All must represent a valid Gregorian date.
+    hour:
+        The hour of the day expressed as a decimal number.  It can be negative
+        or exceed 24; the function will normalise it automatically.
+
+    Returns
+    -------
+    float
+        The Julian Day Number (JD) for the given instant.  The fractional part
+        of the result contains the time of day as a fraction of a day.
+
+    Examples
+    --------
+    >>> julian_day(2000, 1, 1, 12.0)
+    2451545.0
+    >>> julian_day(1858, 11, 17, 0.0)
+    2400000.5
+    """
+
+    # Normalise hour to range [0, 24)
+    # This also ensures that day value is accurate if hour pushes it across
+    # midnight (e.g., hour = 26.0 -> next day).
+    day_offset = int(math.floor(hour / 24))
+    hour = hour - day_offset * 24
+    day += day_offset
+
+    # Algorithm from Astronomical Algorithms (Meeus), section 24.
+    if month <= 2:
+        year_p = year - 1
+        month_p = month + 12
+    else:
+        year_p = year
+        month_p = month
+
+    # Compute the integer part of the day count
+    A = year_p // 100
+    B = 2 - A + (A // 4)
+    C = int(365.25 * (year_p + 4716))
+    D = int(30.6001 * (month_p + 1))
+    jd = C + D + day + B - 1524.5
+
+    # Fractional part of the day given by hour
+    jd += hour / 24.0
+    return jd
+
*** End of file ***