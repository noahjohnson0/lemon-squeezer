
# aider chat started at 2026-05-10 10:45:01

> You can skip this check with --no-gitignore  
> Add .aider* to .gitignore (recommended)? (Y)es/(N)o [Yes]: y  
> Added .aider* to .gitignore  
> /Users/noahjohnson0/.local/bin/aider --model ollama_chat/qwen2.5:14b --no-auto-commits --no-show-model-warnings --no-stream --no-pretty --no-analytics --yes-always --message-file /Users/noahjohnson0/repos/lemon-squeezer/evals/great-circle/prompt.md  
> Aider v0.86.2  
> Model: ollama_chat/qwen2.5:14b with whole edit format  
> Git repo: .git with 0 files  
> Repo-map: using 4096.0 tokens, auto refresh  

#### Write `geo.py` exporting two navigation functions:  
####   
#### ```python  
#### def distance_km(lat1: float, lon1: float, lat2: float, lon2: float) -> float:  
####     """Great-circle distance in kilometres using the haversine formula.  
####     Use mean Earth radius R = 6371.0088 km. All inputs in decimal degrees."""  
####   
#### def bearing_deg(lat1: float, lon1: float, lat2: float, lon2: float) -> float:  
####     """Initial forward azimuth from point 1 to point 2, in degrees, normalized to [0, 360).  
####     0° = north, 90° = east. Standard formula:  
####        theta = atan2(sin(dLon)*cos(lat2), cos(lat1)*sin(lat2) - sin(lat1)*cos(lat2)*cos(dLon))  
####     Inputs in decimal degrees."""  
#### ```  
####   
#### Use `math.radians`, `math.sin/cos/atan2/asin/sqrt`. Pure stdlib, no third-party deps.  
#### For identical points, distance must be 0.0 and bearing must not crash (return 0.0).  
####   
#### Create only `geo.py`. Don't run it.  

geo.py
```
import math

def distance_km(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Great-circle distance in kilometres using the haversine formula.
    Use mean Earth radius R = 6371.0088 km. All inputs in decimal degrees."""
    
    # Convert latitude and longitude from degrees to radians
    lat1_rad = math.radians(lat1)
    lon1_rad = math.radians(lon1)
    lat2_rad = math.radians(lat2)
    lon2_rad = math.radians(lon2)

    # Haversine formula components
    dlat = lat2_rad - lat1_rad
    dlon = lon2_rad - lon1_rad

    a = math.sin(dlat / 2)**2 + math.cos(lat1_rad) * math.cos(lat2_rad) * math.sin(dlon / 2)**2
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))

    # Distance in kilometers using the mean Earth radius R = 6371.0088 km
    distance_km = 6371.0088 * c

    return distance_km


def bearing_deg(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Initial forward azimuth from point 1 to point 2, in degrees, normalized to [0, 360).
    0° = north, 90° = east. Standard formula:
       theta = atan2(sin(dLon)*cos(lat2), cos(lat1)*sin(lat2) - sin(lat1)*cos(lat2)*cos(dLon))
    Inputs in decimal degrees."""
    
    # Convert latitude and longitude from degrees to radians
    lat1_rad = math.radians(lat1)
    lon1_rad = math.radians(lon1)
    lat2_rad = math.radians(lat2)
    lon2_rad = math.radians(lon2)

    dlon = lon2_rad - lon1_rad

    y = math.sin(dlon) * math.cos(lat2_rad)
    x = math.cos(lat1_rad) * math.sin(lat2_rad) - math.sin(lat1_rad) * math.cos(lat2_rad) * math.cos(dlon)

    # Calculate bearing in radians and convert to degrees
    theta = math.atan2(y, x)
    
    # Normalize the result to [0, 360)
    bearing_degrees = (math.degrees(theta) + 360) % 360

    return bearing_degrees


# Example usage:
if __name__ == "__main__":
    print(distance_km(52.20472, 0.14286, 49.08861, 8.20370))
    print(bearing_deg(52.20472, 0.14286, 49.08861, 8.20370))
```

Note: The example usage in the `if __name__ == "__main__":` block is for demonstration purposes and can be removed or modified as needed.

> Tokens: 849 sent, 682 received.  
> geo.py  
> Create new file? (Y)es/(N)o [Yes]: y  
> Applied edit to geo.py  
