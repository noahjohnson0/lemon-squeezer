Write `dates.py` exporting:

```python
def easter(year: int) -> tuple[int, int, int]:
    """Western (Gregorian) Easter date via the Anonymous Gregorian / Meeus-Jones-Butcher algorithm.
    Returns (year, month, day). Valid for year >= 1583; raise ValueError for earlier years."""

def julian_day(year: int, month: int, day: int, hour: float = 0.0) -> float:
    """Julian Day Number for a UTC instant on the proleptic Gregorian calendar.
    Hour is decimal (e.g. 12.0 for noon). Returns float JD."""
```

Pure stdlib (math). No third-party packages, no `dateutil`, no `astropy`.

Reference values:
- easter(2024) == (2024, 3, 31)
- easter(2025) == (2025, 4, 20)
- easter(2026) == (2026, 4, 5)
- julian_day(2000, 1, 1, 12.0) == 2451545.0  (J2000.0 epoch)
- julian_day(1858, 11, 17, 0.0) == 2400000.5  (MJD epoch)

Create only `dates.py`. Don't run it.
