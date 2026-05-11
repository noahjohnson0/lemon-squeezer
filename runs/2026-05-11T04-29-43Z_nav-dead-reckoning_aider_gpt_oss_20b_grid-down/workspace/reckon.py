#!/usr/bin/env python3
"""
Dead-reckoning navigation utilities.

This module provides functions to predict a new geographic position
given a starting point, heading, speed, and elapsed time, as well as
to apply a sequence of such legs.

The calculations assume a spherical Earth with a mean radius of
6371.0 km.  Speed is specified in knots (nautical miles per hour),
where 1 knot = 1.852 km/h.
"""

from __future__ import annotations

import math
from typing import Iterable, List, Tuple

# Constants
EARTH_RADIUS_KM: float = 6371.0
NM_TO_KM: float = 1.852

def _normalize_lon(lon_deg: float) -> float:
    """
    Normalize longitude to the range [-180, 180).
    """
    return ((lon_deg + 180.0) % 360.0) - 180.0

def dead_reckon(
    lat: float,
    lon: float,
    bearing_deg: float,
    speed_kt: float,
    hours: float,
) -> Tuple[float, float]:
    """
    Predict a new latitude/longitude after moving from a starting point
    with a given heading, speed, and duration.

    Parameters
    ----------
    lat : float
        Starting latitude in degrees.
    lon : float
        Starting longitude in degrees.
    bearing_deg : float
        Bearing in degrees from true north (0 = N, 90 = E, 180 = S, 270 = W).
    speed_kt : float
        Speed in knots (nautical miles per hour).
    hours : float
        Duration in hours.

    Returns
    -------
    Tuple[float, float]
        Predicted (latitude, longitude) in degrees.
    """
    # Convert inputs to radians
    lat_rad = math.radians(lat)
    lon_rad = math.radians(lon)
    bearing_rad = math.radians(bearing_deg)

    # Distance travelled in km
    distance_km = speed_kt * NM_TO_KM * hours

    # Angular distance
    delta = distance_km / EARTH_RADIUS_KM

    # Compute new latitude
    sin_lat2 = math.sin(lat_rad) * math.cos(delta) + \
               math.cos(lat_rad) * math.sin(delta) * math.cos(bearing_rad)
    lat2_rad = math.asin(sin_lat2)

    # Compute new longitude
    y = math.sin(bearing_rad) * math.sin(delta) * math.cos(lat_rad)
    x = math.cos(delta) - math.sin(lat_rad) * math.sin(lat2_rad)
    lon2_rad = lon_rad + math.atan2(y, x)

    # Convert back to degrees
    lat2_deg = math.degrees(lat2_rad)
    lon2_deg = math.degrees(lon2_rad)

    # Normalize longitude to [-180, 180)
    lon2_deg = _normalize_lon(lon2_deg)

    return lat2_deg, lon2_deg

def reckon_track(
    start: Tuple[float, float],
    legs: Iterable[Tuple[float, float, float]],
) -> List[Tuple[float, float]]:
    """
    Apply a sequence of navigation legs to a starting point.

    Each leg is a tuple of (bearing_deg, speed_kt, hours).

    Parameters
    ----------
    start : Tuple[float, float]
        Starting latitude and longitude in degrees.
    legs : Iterable[Tuple[float, float, float]]
        Sequence of legs to apply.

    Returns
    -------
    List[Tuple[float, float]]
        List of waypoints including the starting point and each
        intermediate point after applying a leg.
    """
    waypoints: List[Tuple[float, float]] = [start]
    current_lat, current_lon = start

    for bearing_deg, speed_kt, hours in legs:
        current_lat, current_lon = dead_reckon(
            current_lat, current_lon, bearing_deg, speed_kt, hours
        )
        waypoints.append((current_lat, current_lon))

    return waypoints

__all__ = [
    "dead_reckon",
    "reckon_track",
]
