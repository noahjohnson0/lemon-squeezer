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
    # Step 1: Compute Julian Day
    if month == 1 or month == 2:
        year -= 1
        month += 12
    A = year // 100
    B = 2 - A // 4
    julian_day = (365.25 * (year + 4716)) + (30.6001 * (month + 1)) + day + 1721013.5 + hour - 12
    julian_day += B

    # Step 2: Compute Julian Century
    T = (julian_day - 2451545) / 36525

    # Step 3: Mean longitude
    L0 = 280.46646 + 36000.76983 * T
    L0 %= 360

    # Step 4: Mean anomaly
    M = 357.52911 + 35999.05029 * T
    M %= 360

    # Step 5: Equation of the center
    C = 1.9148 * math.sin(math.radians(M)) + 0.01997 * math.sin(math.radians(2 * M)) + 0.00027 * math.sin(math.radians(3 * M))
    true_longitude = L0 + M + C
    true_longitude %= 360

    # Step 6: Obliquity
    epsilon = 23.439 - 0.00000036 * (julian_day - 2451545)
    epsilon = math.radians(epsilon)

    # Step 7: Right ascension and declination
    # Convert true longitude to radians
    true_longitude_rad = math.radians(true_longitude)
    # Compute the sun's coordinates
    sin_true_lon = math.sin(true_longitude_rad)
    cos_true_lon = math.cos(true_longitude_rad)
    sin_epsilon = math.sin(epsilon)
    cos_epsilon = math.cos(epsilon)

    # Right ascension
    sin_ra = sin_true_lon * cos_epsilon
    cos_ra = math.sqrt(1 - sin_ra**2)
    ra = math.degrees(math.atan2(sin_ra, cos_ra))
    ra %= 360

    # Declination
    dec = math.degrees(math.asin(sin_true_lon * sin_epsilon))

    # Step 8: Local sidereal time
    # Compute Greenwich Mean Sidereal Time
    GMST = 280.46061837 + 360.98564736 * T
    GMST %= 360

    # Convert to hours
    GMST_hours = GMST / 15
    GMST_hours %= 24

    # Local sidereal time
    lst = GMST_hours + lon / 15
    lst %= 24
    lst_deg = lst * 15

    # Step 9: Hour angle
    # Convert right ascension to degrees
    ra_deg = ra
    # Compute hour angle
    ha = lst_deg - ra_deg
    ha %= 360

    # Step 10: Altitude and azimuth
    # Convert latitude to radians
    lat_rad = math.radians(lat)
    # Convert hour angle to radians
    ha_rad = math.radians(ha)
    # Convert declination to radians
    dec_rad = math.radians(dec)

    # Compute altitude
    sin_alt = math.sin(lat_rad) * math.sin(dec_rad) + math.cos(lat_rad) * math.cos(dec_rad) * math.cos(ha_rad)
    alt_rad = math.asin(sin_alt)
    alt_deg = math.degrees(alt_rad)

    # Compute azimuth
    cos_azi = (math.sin(lat_rad) - math.sin(dec_rad) * math.cos(alt_rad)) / math.cos(dec_rad) / math.cos(ha_rad)
    sin_azi = -math.sin(ha_rad) * math.cos(dec_rad) / math.cos(alt_rad)
    azi_rad = math.atan2(sin_azi, cos_azi)
    azi_deg = math.degrees(azi_rad)

    # Normalize azimuth to [0, 360)
    azi_deg = (azi_deg + 360) % 360

    return (alt_deg, azi_deg)
