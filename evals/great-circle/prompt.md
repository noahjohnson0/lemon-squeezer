Write `geo.py` exporting two navigation functions:

```python
def distance_km(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Great-circle distance in kilometres using the haversine formula.
    Use mean Earth radius R = 6371.0088 km. All inputs in decimal degrees."""

def bearing_deg(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Initial forward azimuth from point 1 to point 2, in degrees, normalized to [0, 360).
    0° = north, 90° = east. Standard formula:
       theta = atan2(sin(dLon)*cos(lat2), cos(lat1)*sin(lat2) - sin(lat1)*cos(lat2)*cos(dLon))
    Inputs in decimal degrees."""
```

Use `math.radians`, `math.sin/cos/atan2/asin/sqrt`. Pure stdlib, no third-party deps.
For identical points, distance must be 0.0 and bearing must not crash (return 0.0).

Create only `geo.py`. Don't run it.
