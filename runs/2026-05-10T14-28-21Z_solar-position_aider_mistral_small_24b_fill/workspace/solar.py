import math

def sun_position(lat: float, lon: float, year: int, month: int, day: int,
                 hour: float = 12.0) -> tuple[float, float]:
    """Approximate sun altitude & azimuth (in degrees) for a UTC instant at (lat, lon).

    Inputs:
      lat, lon  — observer geographic coordinates, decimal degrees (lat positive N, lon positive E)
      year/month/day  — UTC date
      hour  — UTC hour as a float (e.g. 12.5 for 12:30 UTC)

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

    # Constants
    JD0 = 2451545.0  # Julian Day for J2000 epoch (2000-01-01T12:00Z)

    # Compute Julian Day and Julian Century
    JD = (year - 1) * 365.25 + day_of_year(year, month, day)
    T = (JD - JD0) / 36525

    # Mean longitude L0, mean anomaly M
    L0 = 280.460 + 36000.77 * T / 36525
    M = 357.528 + 35999.05 * T / 36525

    # Equation of centre and true longitude
    C = (1.915 - 0.0048 * T) * math.sin(math.radians(M)) + \
        (0.020 + 0.0000000036 * T) * math.sin(math.radians(2 * M))
    L = L0 + C

    # Obliquity of the ecliptic
    epsilon = 23.439 - 0.0130042 * T

    # Right ascension and declination
    RA = math.degrees(math.atan2(
        math.sin(math.radians(L)) * math.cos(math.radians(epsilon)),
        math.cos(math.radians(L))
    ))
    dec = math.degrees(math.asin(
        math.sin(math.radians(L)) * math.sin(math.radians(epsilon))
    ))

    # Local sidereal time and hour angle
    GMST0 = 6.697374558 + 1.002737909 * (JD - JD0)
    LMST = GMST0 + lon / 15

    HA = LMST - RA - hour * 15
    if HA < 0:
        HA += 360

    # Altitude and azimuth
    lat_rad = math.radians(lat)
    dec_rad = math.radians(dec)
    HA_rad = math.radians(HA)

    altitude = math.degrees(math.asin(
        math.sin(lat_rad) * math.sin(dec_rad) +
        math.cos(lat_rad) * math.cos(dec_rad) * math.cos(HA_rad)
    ))

    azimuth = 180 - math.degrees(math.atan2(
        math.sin(HA_rad),
        math.tan(lat_rad) * math.cos(dec_rad) - math.cos(HA_rad) * math.sin(dec_rad)
    ))
    if azimuth < 0:
        azimuth += 360

    return altitude, azimuth

def day_of_year(year: int, month: int, day: int) -> float:
    """Calculate the day of the year for a given date."""
    if month <= 2:
        year -= 1
        month += 12
    A = math.floor(year / 100)
    B = 2 - A + math.floor(A / 4)

    return math.floor(365.25 * (year + 4716)) + math.floor(30.6001 * (month + 1)) + day + B - 1524
