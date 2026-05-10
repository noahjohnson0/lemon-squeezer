import math

def distance_km(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Great-circle distance in kilometres using the haversine formula.
    Use mean Earth radius R = 6371.0088 km. All inputs in decimal degrees."""
    if lat1 == lat2 and lon1 == lon2:
        return 0.0

    lat1_rad = math.radians(lat1)
    lon1_rad = math.radians(lon1)
    lat2_rad = math.radians(lat2)
    lon2_rad = math.radians(lon2)

    dlat = lat2_rad - lat1_rad
    dlon = lon2_rad - lon1_rad

    a = math.sin(dlat / 2) ** 2 + math.cos(lat1_rad) * math.cos(lat2_rad) * math.sin(dlon / 2) ** 2
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
    R = 6371.0088
    return R * c

def bearing_deg(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Initial forward azimuth from point 1 to point 2, in degrees, normalized to [0, 360).
    0° = north, 90° = east. Standard formula:
       theta = atan2(sin(dLon)*cos(lat2), cos(lat1)*sin(lat2) - sin(lat1)*cos(lat2)*cos(dLon))
    Inputs in decimal degrees."""
    if lat1 == lat2 and lon1 == lon2:
        return 0.0

    lat1_rad = math.radians(lat1)
    lon1_rad = math.radians(lon1)
    lat2_rad = math.radians(lat2)
    lon2_rad = math.radians(lon2)

    dlon = lon2_rad - lon1_rad

    x = math.sin(dlon) * math.cos(lat2_rad)
    y = math.cos(lat1_rad) * math.sin(lat2_rad) - math.sin(lat1_rad) * math.cos(lat2_rad) * math.cos(dlon)

    theta = math.atan2(x, y)
    bearing_deg = math.degrees(theta)
    return bearing_deg % 360
