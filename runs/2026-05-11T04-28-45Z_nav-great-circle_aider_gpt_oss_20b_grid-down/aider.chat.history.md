
# aider chat started at 2026-05-11 00:28:45

> You can skip this check with --no-gitignore  
> Add .aider* to .gitignore (recommended)? (Y)es/(N)o [Yes]: y  
> Added .aider* to .gitignore  
> /Users/noahjohnson0/.local/bin/aider --model ollama_chat/gpt-oss:20b --no-auto-commits --no-show-model-warnings --no-stream --no-pretty --no-analytics --yes-always --message-file /Users/noahjohnson0/repos/lemon-squeezer/evals/nav-great-circle/prompt.md  
> Aider v0.86.2  
> Model: ollama_chat/gpt-oss:20b with whole edit format  
> Git repo: .git with 0 files  
> Repo-map: using 4096 tokens, auto refresh  

#### Implement great-circle navigation math (haversine distance + initial bearing).  
####   
#### The haversine formula gives shortest distance over the Earth's surface  
#### between two (lat, lon) points:  
####   
#### ```  
#### a = sin²(Δφ/2) + cos(φ₁)·cos(φ₂)·sin²(Δλ/2)  
#### c = 2·atan2(√a, √(1−a))  
#### distance = R · c          (R = mean Earth radius ≈ 6371.0 km)  
#### ```  
####   
#### Initial bearing (forward azimuth, true-north reference) from point 1 to point 2:  
####   
#### ```  
#### θ = atan2(sin(Δλ)·cos(φ₂),  
####           cos(φ₁)·sin(φ₂) − sin(φ₁)·cos(φ₂)·cos(Δλ))  
#### ```  
####   
#### Normalize to [0, 360) degrees.  
####   
#### Create `nav.py` exposing:  
####   
#### ```python  
#### EARTH_RADIUS_KM = 6371.0  
####   
#### def haversine_km(lat1: float, lon1: float, lat2: float, lon2: float) -> float:  
####     """Great-circle distance in kilometers between two (lat, lon) points in degrees."""  
####     ...  
####   
#### def initial_bearing_deg(lat1: float, lon1: float, lat2: float, lon2: float) -> float:  
####     """Initial bearing (forward azimuth) from point 1 to point 2, degrees [0, 360)."""  
####     ...  
####   
#### def cardinal(bearing_deg: float) -> str:  
####     """16-point compass label for a bearing. 'N' is [348.75, 11.25), 'NNE' next, etc."""  
####     ...  
#### ```  
####   
#### Reference cases:  
#### - New York (40.7128, -74.0060) to London (51.5074, -0.1278): ~5570 km, bearing ~51°  
#### - Tokyo (35.6762, 139.6503) to Sydney (-33.8688, 151.2093): ~7825 km, bearing ~170°  
####   
#### Save your code to `nav.py` in the workspace root.  

nav.py
```
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
```

> Tokens: 1.1k sent, 1.1k received.  
> nav.py  
> Create new file? (Y)es/(N)o [Yes]: y  
> Applied edit to nav.py  
