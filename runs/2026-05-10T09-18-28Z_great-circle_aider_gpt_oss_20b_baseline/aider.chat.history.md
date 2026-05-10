
# aider chat started at 2026-05-10 05:18:28

> You can skip this check with --no-gitignore  
> Add .aider* to .gitignore (recommended)? (Y)es/(N)o [Yes]: y  
> Added .aider* to .gitignore  
> /Users/noahjohnson0/.local/bin/aider --model ollama_chat/gpt-oss:20b --no-auto-commits --no-show-model-warnings --no-stream --no-pretty --no-analytics --yes-always --message-file /Users/noahjohnson0/repos/lemon-squeezer/evals/great-circle/prompt.md  
> Aider v0.86.2  
> Model: ollama_chat/gpt-oss:20b with whole edit format  
> Git repo: .git with 0 files  
> Repo-map: using 4096 tokens, auto refresh  

#### Write `geo.py` exporting two navigation functions:  
####   
#### ```python  
#### def distance_km(lat1: float, lon1: float, lat2: float, lon2: float) -> float:  
####     """Great-circle distance in kilometres using the haversine formula.  
####     Use mean Earth radius R = 6371.0088 km. All inputs in decimal degrees."""  
####   
#### def bearing_deg(lat1: float, lon1: float, lat2: float, lon2: float) -> float:  
####     """Initial forward azimuth from point 1 to point 2, in degrees, normalized to [0, 360).  
####     0° = north, 90° = east. Standard formula:  
####        theta = atan2(sin(dLon)*cos(lat2), cos(lat1)*sin(lat2) - sin(lat1)*cos(lat2)*cos(dLon))  
####     Inputs in decimal degrees."""  
#### ```  
####   
#### Use `math.radians`, `math.sin/cos/atan2/asin/sqrt`. Pure stdlib, no third-party deps.  
#### For identical points, distance must be 0.0 and bearing must not crash (return 0.0).  
####   
#### Create only `geo.py`. Don't run it.  

geo.py
```
import math
from typing import Tuple

__all__ = ["distance_km", "bearing_deg"]

# Mean Earth radius in kilometres
EARTH_RADIUS_KM = 6371.0088


def _to_radians(deg: float) -> float:
    """Convert degrees to radians."""
    return math.radians(deg)


def distance_km(
    lat1: float, lon1: float, lat2: float, lon2: float
) -> float:
    """
    Great-circle distance in kilometres using the haversine formula.
    Use mean Earth radius R = 6371.0088 km. All inputs in decimal degrees.
    """
    # Convert all coordinates to radians
    φ1, λ1 = _to_radians(lat1), _to_radians(lon1)
    φ2, λ2 = _to_radians(lat2), _to_radians(lon2)

    dφ = φ2 - φ1
    dλ = λ2 - λ1

    sin_dφ_2 = math.sin(dφ / 2.0)
    sin_dλ_2 = math.sin(dλ / 2.0)

    a = sin_dφ_2 * sin_dφ_2 + math.cos(φ1) * math.cos(φ2) * sin_dλ_2 * sin_dλ_2
    c = 2.0 * math.asin(math.sqrt(a))

    return EARTH_RADIUS_KM * c


def bearing_deg(
    lat1: float, lon1: float, lat2: float, lon2: float
) -> float:
    """
    Initial forward azimuth from point 1 to point 2, in degrees, normalized to [0, 360).
    0° = north, 90° = east. Standard formula:
       theta = atan2(sin(dLon)*cos(lat2), cos(lat1)*sin(lat2) - sin(lat1)*cos(lat2)*cos(dLon))
    Inputs in decimal degrees.
    """
    # Handle identical points explicitly to avoid atan2(0, 0)
    if lat1 == lat2 and lon1 == lon2:
        return 0.0

    # Convert to radians
    φ1, λ1 = _to_radians(lat1), _to_radians(lon1)
    φ2, λ2 = _to_radians(lat2), _to_radians(lon2)

    dλ = λ2 - λ1

    y = math.sin(dλ) * math.cos(φ2)
    x = (
        math.cos(φ1) * math.sin(φ2)
        - math.sin(φ1) * math.cos(φ2) * math.cos(dλ)
    )

    θ_rad = math.atan2(y, x)
    θ_deg = math.degrees(θ_rad)

    # Normalize to [0, 360)
    return (θ_deg + 360.0) % 360.0
```

> Tokens: 904 sent, 1.2k received.  
> geo.py  
> Create new file? (Y)es/(N)o [Yes]: y  
> Applied edit to geo.py  
