import subprocess
import json
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

def parse_airport_output(output: str) -> dict:
    data = {}
    for line in output.splitlines():
        line = line.strip()
        if not line:
            continue
        if ':' not in line:
            continue
        key, value = [s.strip() for s in line.split(':', 1)]
        data[key.lower()] = value
    return data

def get_wifi_info() -> dict:
    # Try airport -I
    try:
        result = subprocess.run(
            ["/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport", "-I"],
            capture_output=True,
            text=True,
            check=True,
        )
        info = parse_airport_output(result.stdout)
    except Exception:
        # Fallback to system_profiler
        try:
            result = subprocess.run(
                ["system_profiler", "SPAirPortDataType", "-detailLevel", "mini", "-json"],
                capture_output=True,
                text=True,
                check=True,
            )
            json_output = result.stdout
            data = json.loads(json_output)
            interface = next(iter(data["SPAirPortDataType"]))
            info = interface
        except Exception:
            info = {}

    ssid = info.get("ssid") or ""
    bssid = info.get("bssid") or ""
    rssi = int(info.get("agrctlrssi") or info.get("rssi") or 0)
    channel = info.get("channel") or ""
    tx_rate = info.get("txrate") or ""
    security = info.get("security") or ""

    return {
        "ssid": ssid,
        "bssid": bssid,
        "rssi": rssi,
        "channel": channel,
        "tx_rate": tx_rate,
        "security": security,
    }

@app.get("/api/wifi")
async def wifi():
    return get_wifi_info()
