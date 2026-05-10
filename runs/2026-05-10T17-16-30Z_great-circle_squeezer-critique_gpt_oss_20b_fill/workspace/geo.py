"""Geodesic utilities.

This module implements two basic spherical Earth navigation helpers
using the haversine formula for great‑circle distance and a standard
formula for the initial forward azimuth (bearing) between two points.

All inputs are in decimal degrees; outputs are in kilometres for
:func:`distance_km` and in degrees for :func:`bearing_deg`.

The functions are intentionally lightweight and rely only on the
Python standard library – in particular :mod:`math` – so they can be
used as drop‑in utilities in any project.

``geo.py`` is designed for educational use and follows the
specifications given by the user.  Identical points are handled
gracefully: the distance is zero and the bearing is defined as
``0.0`` instead of raising an exception.
"""

from __future__ import annotations

import math

# Mean Earth radius in kilometres as specified
EARTH_RADIUS_KM: float = 6371.0088

__all__ = ["distance_km", "bearing_deg"]


def distance_km(
    lat1: float, lon1: float, lat2: float, lon2: float
) -> float:
    """Great‑circle distance in kilometres using the haversine formula.

    Parameters
    ----------
    lat1, lon1, lat2, lon2:
        Coordinates in decimal degrees.

    Returns
    -------
    float
        Distance between the two points in kilometres.

    Notes
    -----
    The haversine formula is robust for all valid input values.
    When the two coordinates are identical the result is exactly
    ``0.0``.
    """
    # Convert decimal degrees to radians
    φ1, λ1 = math.radians(lat1), math.radians(lon1)
    φ2, λ2 = math.radians(lat2), math.radians(lon2)

    dφ = φ2 - φ1
    dλ = λ2 - λ1

    # If the points coincide, the distance is zero
    if dφ == 0.0 and dλ == 0.0:
        return 0.0

    a = math.sin(dφ / 2.0) ** 2 + math.cos(φ1) * math.cos(φ2) * math.sin(dλ / 2.0) ** 2
    c = 2.0 * math.asin(math.sqrt(a))
    return EARTH_RADIUS_KM * c


def bearing_deg(
    lat1: float, lon1: float, lat2: float, lon2: float
) -> float:
    """Initial forward azimuth from point 1 to point 2.

    The returned bearing is normalised to the interval
    :math:`[0, 360)` degrees; ``0°`` indicates north and ``90°`` east.

    Parameters
    ----------
    lat1, lon1, lat2, lon2:
        Coordinates in decimal degrees.

    Returns
    -------
    float
        Bearing in degrees.

    Notes
    -----
    If the two coordinates are identical the function returns
    ``0.0`` rather than throwing an exception.
    """
    # Normalise the case where the points are identical
    if lat1 == lat2 and lon1 == lon2:
        return 0.0

    φ1, λ1 = math.radians(lat1), math.radians(lon1)
    φ2, λ2 = math.radians(lat2), math.radians(lon2)
    dλ = λ2 - λ1

    y = math.sin(dλ) * math.cos(φ2)
    x = math.cos(φ1) * math.sin(φ2) - math.sin(φ1) * math.cos(φ2) * math.cos(dλ)
    bearing_rad = math.atan2(y, x)
    bearing_deg = math.degrees(bearing_rad)
    # Normalise to [0, 360)
    return (bearing_deg + 360.0) % 360.0


# If executed as a script, run a tiny demo to sanity‑check the functions.
if __name__ == "__main__":  # pragma: no cover
    # Example: Paris (48.8566, 2.3522) to New York (40.7128, -74.0060)
    d = distance_km(48.8566, 2.3522, 40.7128, -74.0060)
    b = bearing_deg(48.8566, 2.3522, 40.7128, -74.0060)
    print(f"Distance: {d:.2f} km, Bearing: {b:.2f}°")
