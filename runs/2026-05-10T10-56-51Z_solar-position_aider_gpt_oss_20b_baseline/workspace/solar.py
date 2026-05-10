import math

def _julian_day(year: int, month: int, day: int, hour: float) -> float:
    """
    Compute Julian Day for a given UTC date and hour.
    """
    if month <= 2:
        year -= 1
        month += 12
    A = math.floor(year / 100)
    B = 2 - A + math.floor(A / 4)
    JD = (
        math.floor(365.25 * (year + 4716))
        + math.floor(30.6001 * (month + 1))
        + day
        + B
        - 1524.5
        + hour / 24.0
    )
    return JD


def sun_position(
    lat: float,
    lon: float,
    year: int,
    month: int,
    day: int,
    hour: float = 12.0,
) -> tuple[float, float]:
    """
    Approximate sun altitude & azimuth (in degrees) for a UTC instant at (lat, lon).

    Inputs:
      lat, lon  — observer geographic coordinates, decimal degrees (lat positive N, lon positive E)
      year/month/day  — UTC date
      hour  — UTC hour as a float (e.g. 12.5 for 12:30 UTC)

    Returns (altitude_deg, azimuth_deg) where:
      altitude is the angle of the sun above the horizon (negative below)
      azimuth is measured clockwise from north (0=N, 90=E, 180=S, 270=W), normalised to [0, 360)

    Uses the NOAA-style algorithm.
    """
    # 1. Julian Day and Century
    JD = _julian_day(year, month, day, hour)
    T = (JD - 2451545.0) / 36525.0

    # 2. Mean longitude, mean anomaly, equation of centre, true longitude
    L0 = (280.46646 + 36000.76983 * T + 0.0003032 * T * T) % 360
    M = (357.52911 + 35999.05029 * T - 0.0001537 * T * T) % 360

    C = (
        (1.914602 - 0.004817 * T - 0.000014 * T * T) * math.sin(math.radians(M))
        + (0.019993 - 0.000101 * T) * math.sin(math.radians(2 * M))
        + 0.000289 * math.sin(math.radians(3 * M))
    )

    true_long = (L0 + C) % 360

    # 3. Obliquity
    epsilon0 = 23.439291 - 0.0130042 * T
    epsilon = epsilon0 + 0.00256 * math.cos(math.radians(125.04 - 1934.136 * T))

    # 4. Right ascension and declination
    alpha = math.degrees(
        math.atan2(
            math.cos(math.radians(epsilon)) * math.sin(math.radians(true_long)),
            math.cos(math.radians(true_long)),
        )
    ) % 360

    delta = math.degrees(
        math.asin(
            math.sin(math.radians(epsilon)) * math.sin(math.radians(true_long))
        )
    )

    # 5. Local sidereal time and hour angle
    GMST = (
        280.46061837
        + 360.98564736629 * (JD - 2451545)
        + 0.000387933 * T * T
        - T * T * T / 38710000
    ) % 360

    LST = (GMST + lon) % 360
    H = (LST - alpha) % 360
    if H > 180:
        H -= 360

    # 6. Altitude and azimuth
    lat_rad = math.radians(lat)
    H_rad = math.radians(H)
    delta_rad = math.radians(delta)

    alt_rad = math.asin(
        math.sin(lat_rad) * math.sin(delta_rad)
        + math.cos(lat_rad) * math.cos(delta_rad) * math.cos(H_rad)
    )
    altitude_deg = math.degrees(alt_rad)

    az_rad = math.acos(
        (
            math.sin(delta_rad)
            - math.sin(alt_rad) * math.sin(lat_rad)
        )
        / (math.cos(alt_rad) * math.cos(lat_rad))
    )
    azimuth_deg = math.degrees(az_rad)
    if math.sin(H_rad) > 0:
        azimuth_deg = 360 - azimuth_deg

    azimuth_deg = azimuth_deg % 360

    return altitude_deg, azimuth_deg
