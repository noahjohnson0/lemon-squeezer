Implement dead-reckoning navigation: predict a new position from a starting
point, heading, speed, and elapsed time. Useful when GPS is unavailable.

Inputs:
- starting (lat, lon) in degrees
- bearing in degrees from true north (0 = N, 90 = E, 180 = S, 270 = W)
- speed in knots (nautical miles per hour, where 1 nm = 1.852 km)
- duration in hours

Forward formula (spherical Earth, mean radius R = 6371.0 km):
```
distance_km = speed_kt × 1.852 × duration_hr
δ = distance_km / R               # angular distance, radians
lat2 = asin(sin(lat1)·cos(δ) + cos(lat1)·sin(δ)·cos(bearing))
lon2 = lon1 + atan2(sin(bearing)·sin(δ)·cos(lat1),
                    cos(δ) − sin(lat1)·sin(lat2))
```

Create `reckon.py` exposing:

```python
EARTH_RADIUS_KM = 6371.0
NM_TO_KM = 1.852

def dead_reckon(lat: float, lon: float, bearing_deg: float,
                speed_kt: float, hours: float) -> tuple[float, float]:
    """Return predicted (lat, lon) after the given heading + speed for the given duration."""
    ...

def reckon_track(start: tuple[float, float],
                 legs: list[tuple[float, float, float]]) -> list[tuple[float, float]]:
    """Apply a sequence of legs, each (bearing_deg, speed_kt, hours).
       Return the list of waypoints including the start.
       For example, legs=[(90, 10, 1), (0, 10, 1)] means 'east at 10kt for 1h, then north at 10kt for 1h'."""
    ...
```

Reference: from (40.0, -74.0), heading 90° at 10 kt for 1 hour should give
approximately (40.000, -73.782) — about 18.5 km east. Normalize output
longitude to [-180, 180).

Save your code to `reckon.py` in the workspace root.
