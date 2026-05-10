"""
Solar position approximation using NOAA algorithm.

This module provides a single function ``sun_position`` which returns the
solar altitude and azimuth for a given UTC instant and observer location.

The algorithm follows the NOAA Solar Calculator procedure and is
implemented only with the Python standard library.
"""

from __future__ import annotations

import math
from typing import Tuple

# -----------------------------------------------------------------------------
# Constants
# -----------------------------------------------------------------------------
# Earth‐obliquity at J2000.0 – used for the simple NOAA algorithm.
_EPS0_DEG = 23.43929111  # degrees
_EPS0_RAD = math.radians(_EPS0_DEG)

# Helper functions
# -----------------------------------------------------------------------------

def _normalize_angle_deg(angle: float) -> float:
    """Return *angle* normalised to [0, 360)."""
    return angle % 360.0


def _clamp(x: float, lower: float = -1.0, upper: float = 1.0) -> float:
    """Clamp *x* to the inclusive range ``[lower, upper]``.

    The function exists only to keep the core algorithm concise; it also
    expresses an understanding that trigonometric expressions can exceed the
    [-1, 1] domain slightly because of rounding errors.
    """
    return max(lower, min(upper, x))

# -----------------------------------------------------------------------------
# Main API
# -----------------------------------------------------------------------------

def sun_position(
    lat: float,
    lon: float,
    year: int,
    month: int,
    day: int,
    hour: float = 12.0,
) -> Tuple[float, float]:
    """Approximate sun altitude & azimuth (in degrees) for a UTC instant.

    Parameters
    ----------
    lat, lon:
        Geographic coordinates in decimal degrees. Latitude must be in
        [-90, 90] (north positive), longitude in [-180, 180] (east positive).
    year, month, day:
        UTC date.
    hour:
        Fractional UTC hour (e.g. 12.5 for 12:30 UTC).  ``hour`` must be in the
        range ``0 <= hour < 24`` – a :class:`ValueError` is raised otherwise.

    Returns
    -------
    tuple[float, float]
        *(altitude_deg, azimuth_deg)* where altitude is the angle of the sun
        above the horizon (negative when below) and azimuth is measured
        clockwise from north, normalised to [0, 360).
    """
    # ------------------------------------------------------------------
    # 0. Sanity checks
    # ------------------------------------------------------------------
    if not (0.0 <= hour < 24.0):
        raise ValueError("hour must be a fractional value in [0, 24). Got %r" % hour)

    # ------------------------------------------------------------------
    # 1. Julian Day (JD) – from Meeus, *Astronomical Algorithms*
    # ------------------------------------------------------------------
    if month <= 2:
        y = year - 1
        m = month + 12
    else:
        y = year
        m = month
    A = math.floor(y / 100)
    B = 2 - A + math.floor(A / 4)
    jd_day = math.floor(365.25 * (y + 4716)) + math.floor(30.6001 * (m + 1)) + day + B - 1524.5
    jd = jd_day + hour / 24.0

    # ------------------------------------------------------------------
    # 2. Julian Century (T)
    # ------------------------------------------------------------------
    T = (jd - 2451545.0) / 36525.0

    # ------------------------------------------------------------------
    # 3. Sun geometry – mean longitude, mean anomaly, equation of centre
    # ------------------------------------------------------------------
    L0 = _normalize_angle_deg(280.46646 + 36000.76983 * T + 0.0003032 * T * T)  # mean solar longitude
    M = _normalize_angle_deg(357.52911 + 35999.05029 * T - 0.0001537 * T * T)  # mean anomaly
    M_rad = math.radians(M)
    C = (1.914602 - 0.004817 * T - 0.000014 * T * T) * math.sin(M_rad)  # equation of centre
    ecliptic_long = _normalize_angle_deg(L0 + C)  # true longitude (ε ≈ 0)

    # ------------------------------------------------------------------
    # 4. Apparent longitude and right ascension/declination
    # ------------------------------------------------------------------
    omega = 125.04 - 0.052954 * T
    omega_rad = math.radians(omega)
    # Apparent longitude – correct NOAA expression
    lambda_sun = _normalize_angle_deg(
        ecliptic_long + 0.0053 * math.sin(omega_rad) - 0.0069 * math.sin(2 * omega_rad)
    )
    lambda_rad = math.radians(lambda_sun)

    # Right ascension (RA) – latitude in the ecliptic plane is ≈0.
    sin_lambda = math.sin(lambda_rad)
    cos_lambda = math.cos(lambda_rad)
    sin_eps = math.sin(_EPS0_RAD)
    cos_eps = math.cos(_EPS0_RAD)
    RA_rad = math.atan2(sin_lambda * cos_eps, cos_lambda)
    RA_deg = math.degrees(RA_rad)
    RA_deg = _normalize_angle_deg(RA_deg)

    # Declination
    sin_decl = sin_lambda * sin_eps
    decl_rad = math.asin(_clamp(sin_decl))

    # ------------------------------------------------------------------
    # 5. Greenwich mean sidereal time (GMST) – Meeus, p. 156
    # ------------------------------------------------------------------
    gmst = 280.0 + 360.98564736629 * (jd - 2451545.0) + 0.000387933 * T * T - (T * T * T) / 38710000.0
    gmst_deg = _normalize_angle_deg(gmst)

    # ------------------------------------------------------------------
    # 6. Local sidereal time (LST)
    # ------------------------------------------------------------------
    lst_deg = _normalize_angle_deg(gmst_deg + lon)

    # ------------------------------------------------------------------
    # 7. Hour angle
    # ------------------------------------------------------------------
    H_deg = lst_deg - RA_deg
    H_deg = (H_deg + 180.0) % 360.0 - 180.0  # wrap to [-180, 180]
    H_rad = math.radians(H_deg)

    # ------------------------------------------------------------------
    # 8. Altitude
    # ------------------------------------------------------------------
    sin_lat = math.sin(math.radians(lat))
    cos_lat = math.cos(math.radians(lat))
    sin_decl = math.sin(decl_rad)
    cos_decl = math.cos(decl_rad)
    sin_alt = sin_lat * sin_decl + cos_lat * cos_decl * math.cos(H_rad)
    sin_alt = _clamp(sin_alt)
    altitude_rad = math.asin(sin_alt)
    altitude_deg = math.degrees(altitude_rad)

    # ------------------------------------------------------------------
    # 9. Azimuth – NOAA uses a formula that gives azimuth from north.
    # ------------------------------------------------------------------
    az_rad = math.atan2(
        math.sin(H_rad),
        math.cos(H_rad) * sin_lat - math.tan(decl_rad) * math.cos(math.radians(lat))
    )
    az_deg = _normalize_angle_deg(math.degrees(az_rad))

    return altitude_deg, az_deg

__all__ = ["sun_position"]
""