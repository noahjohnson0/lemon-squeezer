import math

def easter(year: int) -> tuple[int, int, int]:
    """Western (Gregorian) Easter date via the Anonymous Gregorian / Meeus-Jones-Butcher algorithm.
    Returns (year, month, day). Valid for year >= 1583; raise ValueError for earlier years."""
    if year < 1583:
        raise ValueError("Year must be 1583 or later")

    a = year % 19
    b = year // 100
    c = year % 100
    d = b // 4
    e = b % 4
    f = (b + 8) // 25
    g = (b - f + 1) // 3
    h = (19 * a + b - d - g + 15) % 30
    i = c // 4
    k = c % 4
    l = (32 + 2 * e + 2 * i - h - k) % 7
    m = (a + 11 * h + 22 * l) // 451
    month = (h + l - 7 * m + 114) // 31
    day = ((h + l - 7 * m + 114) % 31) + 1

    return year, month, day

def julian_day(year: int, month: int, day: int, hour: float = 0.0) -> float:
    """Julian Day Number for a UTC instant on the proleptic Gregorian calendar.
    Hour is decimal (e.g. 12.0 for noon). Returns float JD."""
    if month <= 2:
        year -= 1
        month += 12

    A = year // 100
    B = 2 - A + A // 4

    return math.floor(365.25 * (year + 4716)) + math.floor(30.6001 * (month + 1)) + day + hour / 24 + B - 1524
