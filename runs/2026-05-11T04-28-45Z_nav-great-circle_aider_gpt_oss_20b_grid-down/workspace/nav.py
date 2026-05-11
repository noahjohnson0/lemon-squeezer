"""
Great-circle navigation utilities.

Provides functions to compute the haversine distance, initial bearing,
and a 16-point compass cardinal direction for a given bearing.
"""

import math

# Mean Earth radius in kilometers
EARTH_RADIUS_KM = 6371.0

# 16-point compass labels in order starting from North
_COMPOSITE_LABELS = [
    "N", "NNE", "NE", "ENE",
    "E", "ESE", "SE", "SSE",
    "S", "SSW", "SW", "WSW",
    "W", "WNW", "NW", "NNW"
]

def _deg_to_rad(deg: float) -> float:
    """Convert degrees to radians."""
    return deg * math.pi / 180.0

def _rad_to_deg(rad: float) -> float:
    """Convert radians to degrees."""
    return rad * 180.0 / math.pi

def haversine_km(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """
    Compute the great-circle distance between two points on the Earth
    specified by latitude/longitude in degrees.

    Parameters
    ----------
    lat1, lon1 : float
        Latitude and longitude of the first point in degrees.
    lat2, lon2 : float
        Latitude and longitude of the second point in degrees.

    Returns
    -------
    float
        Distance in kilometers.
    """
    # Convert coordinates to radians
    φ1, λ1 = _deg_to_rad(lat1), _deg_to_rad(lon1)
    φ2, λ2 = _deg_to_rad(lat2), _deg_to_rad(lon2)

    Δφ = φ2 - φ1
    Δλ = λ2 - λ1

    a = math.sin(Δφ / 2.0) ** 2 + \
        math.cos(φ1) * math.cos(φ2) * math.sin(Δλ / 2.0) ** 2
    c = 2.0 * math.atan2(math.sqrt(a), math.sqrt(1.0 - a))

    return EARTH_RADIUS_KM * c

def initial_bearing_deg(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """
    Compute the initial bearing (forward azimuth) from point 1 to point 2.

    Parameters
    ----------
    lat1, lon1 : float
        Latitude and longitude of the starting point in degrees.
    lat2, lon2 : float
        Latitude and longitude of the destination point in degrees.

    Returns
    -------
    float
        Bearing in degrees, normalized to [0, 360).
    """
    φ1, λ1 = _deg_to_rad(lat1), _deg_to_rad(lon1)
    φ2, λ2 = _deg_to_rad(lat2), _deg_to_rad(lon2)

    Δλ = λ2 - λ1

    x = math.sin(Δλ) * math.cos(φ2)
    y = math.cos(φ1) * math.sin(φ2) - \
        math.sin(φ1) * math.cos(φ2) * math.cos(Δλ)

    θ_rad = math.atan2(x, y)
    θ_deg = (_rad_to_deg(θ_rad) + 360.0) % 360.0
    return θ_deg

def cardinal(bearing_deg: float) -> str:
    """
    Convert a bearing in degrees to a 16-point compass label.

    Parameters
    ----------
    bearing_deg : float
        Bearing in degrees, expected in [0, 360).

    Returns
    -------
    str
        Compass label such as 'N', 'NE', 'SSE', etc.
    """
    # Normalize bearing to [0, 360)
    bearing = bearing_deg % 360.0
    # Each sector is 22.5 degrees; add 11.25 to center the sector
    index = int((bearing + 11.25) / 22.5) % 16
    return _COMPOSITE_LABELS[index]

__all__ = [
    "EARTH_RADIUS_KM",
    "haversine_km",
    "initial_bearing_deg",
    "cardinal"
]
