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

# Helper functions

__DEG_PER_RAD = 180.0 / math.pi
__RAD_PER_DEG = math.pi / 180.0


def _normalize_angle_deg(angle: float) -> float:
    """Return *angle* normalized to [0, 360)."""
    return angle % 360.0

# Main function

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
        Geographic coordinates in decimal degrees.
        Latitude must be in [-90, 90] (north positive), longitude in [-180,
        180] (east positive).
    year, month, day:
        UTC date.
    hour:
        Fractional UTC hour (e.g. 12.5 for 12:30 UTC). Defaults to 12.0.

    Returns
    -------
    tuple[float, float]
        *(altitude_deg, azimuth_deg)* where altitude is the angle of the sun
        above the horizon (negative when below) and azimuth is measured
        clockwise from north, normalised to [0, 360).
    """

    # ---------------------------------------------------------------------
    # 1. Julian Day (JD)
    # ---------------------------------------------------------------------
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

    # ---------------------------------------------------------------------
    # 2. Julian Century (T)
    # ---------------------------------------------------------------------
    T = (jd - 2451545.0) / 36525.0

    # ---------------------------------------------------------------------
    # 3. Sun geometry: mean longitude, anomaly, equation of centre
    # ---------------------------------------------------------------------
    L0 = _normalize_angle_deg(280.46646 + 36000.76983 * T + 0.0003032 * T * T)
    M = _normalize_angle_deg(357.52911 + 35999.05029 * T - 0.0001537 * T * T)
    M_rad = M * __RAD_PER_DEG
    C = 1.914602 - 0.004817 * T - 0.000014 * T * T
    C = C * math.sin(M_rad)
    ecliptic_long = _normalize_angle_deg(L0 + C)

    # ---------------------------------------------------------------------
    # 4. Apparent longitude and right ascension
    # ---------------------------------------------------------------------
    omega = 125.04 - 0.052954 * T
    lambda_sun = _normalize_angle_deg(ecliptic_long - 0.00569 - 0.00478 * math.sin(omega * __RAD_PER_DEG))
    lambda_rad = lambda_sun * __RAD_PER_DEG
    # Convert to right ascension and declination via obliquity
    sin_lambda = math.sin(lambda_rad)
    cos_lambda = math.cos(lambda_rad)
    sin_eps = math.sin(23.43929111 * __RAD_PER_DEG)
    cos_eps = math.cos(23.43929111 * __RAD_PER_DEG)
    sin_beta = sin_eps * sin_lambda
    beta = math.asin(sin_beta)  # not used further
    # Declination
    sin_decl = cos_eps * sin_lambda
    decl = math.asin(sin_decl)

    # ---------------------------------------------------------------------
    # 5. Greenwich mean sidereal time
    # ---------------------------------------------------------------------
    gmst = 280.0 + 360.98564736629 * (jd - 2451545.0) + 0.000387933 * T * T - (T * T * T) / 38710000.0
    gmst_deg = _normalize_angle_deg(gmst)

    # ---------------------------------------------------------------------
    # 6. Local sidereal time
    # ---------------------------------------------------------------------
    lst_deg = _normalize_angle_deg(gmst_deg + lon)

    # ---------------------------------------------------------------------
    # 7. Hour angle
    # ---------------------------------------------------------------------
    # Right ascension (RA) from ecliptic longitude
    RA_deg = _normalize_angle_deg(2 * math.atan2(math.tan(lambda_rad / 2) * math.cos(23.43929111 * __RAD_PER_DEG), 1) * __DEG_PER_RAD)
    H = lst_deg - RA_deg
    # Wrap to [-180, 180]
    H = (H + 180.0) % 360.0 - 180.0
    H_rad = H * __RAD_PER_DEG

    # ---------------------------------------------------------------------
    # 8. Altitude
    # ---------------------------------------------------------------------
    rad_lat = lat * __RAD_PER_DEG
    sin_alt = math.sin(rad_lat) * math.sin(decl) + math.cos(rad_lat) * math.cos(decl) * math.cos(H_rad)
    altitude_rad = math.asin(sin_alt)
    altitude_deg = altitude_rad * __DEG_PER_RAD

    # ---------------------------------------------------------------------
    # 9. Azimuth
    # ---------------------------------------------------------------------
    sin_az = -math.sin(H_rad) * math.cos(decl)
    cos_az = (math.sin(decl) - math.sin(altitude_rad) * math.sin(rad_lat)) / (math.cos(altitude_rad) * math.cos(rad_lat))
    azimuth_rad = math.atan2(sin_az, cos_az)
    azimuth_deg = _normalize_angle_deg(azimuth_rad * __DEG_PER_RAD)

    return altitude_deg, azimuth_deg

__all__ = ["sun_position"]
