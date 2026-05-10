import asyncio
import json
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

app = FastAPI(title="WiFi Info API")

# Allow CORS for all origins (frontend on a different port)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

async def _run_airport_command() -> dict:
    """Run the macOS airport command and parse its output into a dict.
    Returns an empty dict if the command fails.
    """
    cmd = "/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport -I"
    try:
        process = await asyncio.create_subprocess_shell(
            cmd,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
        )
        stdout, stderr = await process.communicate()
        if process.returncode != 0:
            return {}
        output = stdout.decode()
    except Exception:
        return {}

    data = {}
    for line in output.splitlines():
        if ":" not in line:
            continue
        key, value = line.split(":", 1)
        data[key.strip().lower()] = value.strip()
    return data

@app.get("/api/wifi")
async def get_wifi():
    raw = await _run_airport_command()
    if not raw:
        return {
            "ssid": None,
            "bssid": None,
            "rssi": None,
            "channel": None,
            "tx_rate": None,
            "security": None,
        }

    ssid = raw.get("ssid")
    bssid = raw.get("lastbssid") or raw.get("bssid")

    # RSSI: 'agrctlrssi' or 'lastrssi'
    rssi_str = raw.get("agrctlrssi") or raw.get("lastrssi")
    try:
        rssi = int(rssi_str) if rssi_str is not None else None
    except Exception:
        rssi = None

    channel = raw.get("channel")
    try:
        channel = int(channel) if channel is not None else None
    except Exception:
        channel = None

    # TX rate: 'lastrate' or 'lasttxrate' in Mbps
    tx_rate_str = raw.get("lastrate") or raw.get("lasttxrate")
    try:
        tx_rate = float(tx_rate_str) if tx_rate_str is not None else None
    except Exception:
        tx_rate = None

    # Security may appear as 'encryption' key like 'WPA2' or 'WPA3'
    security = raw.get("encryption") or raw.get("security") or None

    return {
        "ssid": ssid,
        "bssid": bssid,
        "rssi": rssi,
        "channel": channel,
        "tx_rate": tx_rate,
        "security": security,
    }

# If the script is run directly, start uvicorn. Users are expected to run via uvicorn.
if __name__ == "__main__":
    import uvicorn

    uvicorn.run("backend.main:app", host="0.0.0.0", port=8000, reload=True)
