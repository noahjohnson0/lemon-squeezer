Write `solar.py` exporting:

```python
def sun_position(lat: float, lon: float, year: int, month: int, day: int,
                 hour: float = 12.0) -> tuple[float, float]:
    """Approximate sun altitude & azimuth (in degrees) for a UTC instant at (lat, lon).

    Inputs:
      lat, lon  - observer geographic coordinates, decimal degrees (lat positive N, lon positive E)
      year/month/day  - UTC date
      hour  - UTC hour as a float (e.g. 12.5 for 12:30 UTC)

    Returns (altitude_deg, azimuth_deg) where:
      altitude is the angle of the sun above the horizon (negative below)
      azimuth is measured clockwise from north (0=N, 90=E, 180=S, 270=W), normalised to [0, 360)

    Use the simple NOAA-style algorithm:
      1. Compute Julian Day, then Julian Century (T = (JD - 2451545) / 36525).
      2. Mean longitude L0, mean anomaly M, equation of centre, true longitude.
      3. Obliquity epsilon ≈ 23.439 - 0.00000036 * (JD-2451545).
      4. Right ascension and declination from true longitude + obliquity.
      5. Local sidereal time and hour angle.
      6. Altitude/azimuth via standard spherical trig.

    Accuracy target: within ±1 degree of NOAA reference values."""
```

Pure stdlib (math). Test against well-known values:
- New York (40.71, -74.01) on 2024-06-21 16:00 UTC (~noon EDT, summer solstice): altitude ~71-72°, azimuth ~178-182° (near south)
- London (51.5, 0) on 2024-12-21 12:00 UTC (winter solstice noon): altitude ~15-16°, azimuth ~178-182°

Create only `solar.py`. Don't run it.
