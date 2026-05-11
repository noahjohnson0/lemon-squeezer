
# aider chat started at 2026-05-11 00:29:43

> You can skip this check with --no-gitignore  
> Add .aider* to .gitignore (recommended)? (Y)es/(N)o [Yes]: y  
> Added .aider* to .gitignore  
> /Users/noahjohnson0/.local/bin/aider --model ollama_chat/gpt-oss:20b --no-auto-commits --no-show-model-warnings --no-stream --no-pretty --no-analytics --yes-always --message-file /Users/noahjohnson0/repos/lemon-squeezer/evals/nav-dead-reckoning/prompt.md  
> Aider v0.86.2  
> Model: ollama_chat/gpt-oss:20b with whole edit format  
> Git repo: .git with 0 files  
> Repo-map: using 4096 tokens, auto refresh  

#### Implement dead-reckoning navigation: predict a new position from a starting  
#### point, heading, speed, and elapsed time. Useful when GPS is unavailable.  
####   
#### Inputs:  
#### - starting (lat, lon) in degrees  
#### - bearing in degrees from true north (0 = N, 90 = E, 180 = S, 270 = W)  
#### - speed in knots (nautical miles per hour, where 1 nm = 1.852 km)  
#### - duration in hours  
####   
#### Forward formula (spherical Earth, mean radius R = 6371.0 km):  
#### ```  
#### distance_km = speed_kt × 1.852 × duration_hr  
#### δ = distance_km / R               # angular distance, radians  
#### lat2 = asin(sin(lat1)·cos(δ) + cos(lat1)·sin(δ)·cos(bearing))  
#### lon2 = lon1 + atan2(sin(bearing)·sin(δ)·cos(lat1),  
####                     cos(δ) − sin(lat1)·sin(lat2))  
#### ```  
####   
#### Create `reckon.py` exposing:  
####   
#### ```python  
#### EARTH_RADIUS_KM = 6371.0  
#### NM_TO_KM = 1.852  
####   
#### def dead_reckon(lat: float, lon: float, bearing_deg: float,  
####                 speed_kt: float, hours: float) -> tuple[float, float]:  
####     """Return predicted (lat, lon) after the given heading + speed for the given duration."""  
####     ...  
####   
#### def reckon_track(start: tuple[float, float],  
####                  legs: list[tuple[float, float, float]]) -> list[tuple[float, float]]:  
####     """Apply a sequence of legs, each (bearing_deg, speed_kt, hours).  
####        Return the list of waypoints including the start.  
####        For example, legs=[(90, 10, 1), (0, 10, 1)] means 'east at 10kt for 1h, then north at 10kt for 1h'."""  
####     ...  
#### ```  
####   
#### Reference: from (40.0, -74.0), heading 90° at 10 kt for 1 hour should give  
#### approximately (40.000, -73.782) — about 18.5 km east. Normalize output  
#### longitude to [-180, 180).  
####   
#### Save your code to `reckon.py` in the workspace root.  

reckon.py
```
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
```

> Tokens: 1.2k sent, 1.1k received.  
> reckon.py  
> Create new file? (Y)es/(N)o [Yes]: y  
> Applied edit to reckon.py  
