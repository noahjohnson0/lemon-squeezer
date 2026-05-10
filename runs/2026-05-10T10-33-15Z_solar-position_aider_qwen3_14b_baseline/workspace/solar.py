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
    a = (14 - month) // 12
    y = year + 4800 - a
    m = month + 12 * a - 3
    jd = day + (153 * m + 2) / 5 + 365 * y + y // 4 - y // 100 + y // 400 - 32075 + hour / 24

    # Step 2: Compute Julian Century
    t = (jd - 2451545) / 36525

    # Step 3: Mean longitude, mean anomaly, equation of centre, true longitude
    l0 = 280.460 + 360.985647 * t
    m = 357.528 + 359.99756 * t
    c = (1.9148 * math.sin(math.radians(m)) +
         0.0200 * math.sin(math.radians(2 * m)) +
         0.0001 * math.sin(math.radians(3 * m)))
    l = l0 + c

    # Step 4: Obliquity
    epsilon = 23.439 - 0.00000036 * (jd - 2451545)

    # Step 5: Right ascension and declination
    # Convert to radians
    l_rad = math.radians(l)
    epsilon_rad = math.radians(epsilon)

    # Right ascension (RA)
    ra_rad = math.atan2(math.sin(l_rad) * math.cos(epsilon_rad),
                         math.cos(l_rad))
    # Declination (Dec)
    dec_rad = math.asin(math.sin(epsilon_rad) * math.sin(l_rad) +
                         math.cos(epsilon_rad) * math.cos(l_rad) * math.cos(math.radians(c)))

    # Convert RA to degrees
    ra_deg = math.degrees(ra_rad)

    # Step 6: Local sidereal time and hour angle
    lst_deg = 280.460 + 360.985647 * t + lon
    ha_deg = lst_deg - ra_deg

    # Step 7: Altitude and azimuth
    lat_rad = math.radians(lat)
    dec_rad = math.radians(dec_rad)
    ha_rad = math.radians(ha_deg)

    # Altitude
    sin_alt = math.sin(lat_rad) * math.sin(dec_rad) + math.cos(lat_rad) * math.cos(dec_rad) * math.cos(ha_rad)
    altitude_deg = math.degrees(math.asin(sin_alt))

    # Azimuth
    tan_az = math.sin(ha_rad) / (math.tan(lat_rad) * math.cos(dec_rad) - math.sin(dec_rad) * math.cos(ha_rad))
    azimuth_rad = math.atan2(tan_az, 1)
    azimuth_deg = math.degrees(azimuth_rad)

    # Normalize azimuth to [0, 360)
    if azimuth_deg < 0:
        azimuth_deg += 360

    return (altitude_deg, azimuth_deg)
