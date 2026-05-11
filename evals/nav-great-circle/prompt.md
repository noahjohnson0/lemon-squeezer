Implement great-circle navigation math (haversine distance + initial bearing).

The haversine formula gives shortest distance over the Earth's surface
between two (lat, lon) points:

```
a = sin²(Δφ/2) + cos(φ₁)·cos(φ₂)·sin²(Δλ/2)
c = 2·atan2(√a, √(1−a))
distance = R · c          (R = mean Earth radius ≈ 6371.0 km)
```

Initial bearing (forward azimuth, true-north reference) from point 1 to point 2:

```
θ = atan2(sin(Δλ)·cos(φ₂),
          cos(φ₁)·sin(φ₂) − sin(φ₁)·cos(φ₂)·cos(Δλ))
```

Normalize to [0, 360) degrees.

Create `nav.py` exposing:

```python
EARTH_RADIUS_KM = 6371.0

def haversine_km(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Great-circle distance in kilometers between two (lat, lon) points in degrees."""
    ...

def initial_bearing_deg(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Initial bearing (forward azimuth) from point 1 to point 2, degrees [0, 360)."""
    ...

def cardinal(bearing_deg: float) -> str:
    """16-point compass label for a bearing. 'N' is [348.75, 11.25), 'NNE' next, etc."""
    ...
```

Reference cases:
- New York (40.7128, -74.0060) to London (51.5074, -0.1278): ~5570 km, bearing ~51°
- Tokyo (35.6762, 139.6503) to Sydney (-33.8688, 151.2093): ~7825 km, bearing ~170°

Save your code to `nav.py` in the workspace root.
