import subprocess
import re
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

app = FastAPI()

# Allow all origins for simplicity
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

class WifiStats(BaseModel):
    ssid: str | None
    bssid: str | None
    rssi: int | None
    channel: int | None
    tx_rate: float | None
    security: str | None

def parse_airport_output(output: str) -> WifiStats:
    # Regex patterns for each field
    patterns = {
        "ssid": r"SSID: (.+)",
        "bssid": r"BSSID: (.+)",
        "rssi": r"agrCtlRSSI: (-?\d+)",
        "channel": r"channel: (\d+)",
        "tx_rate": r"agrCtlTxRate: ([\d\.]+)",
        "security": r"security: (.+)",
    }
    data = {}
    for key, pattern in patterns.items():
        match = re.search(pattern, output)
        data[key] = match.group(1).strip() if match else None

    # Convert types
    try:
        data["rssi"] = int(data["rssi"]) if data["rssi"] is not None else None
    except ValueError:
        data["rssi"] = None
    try:
        data["channel"] = int(data["channel"]) if data["channel"] is not None else None
    except ValueError:
        data["channel"] = None
    try:
        data["tx_rate"] = float(data["tx_rate"]) if data["tx_rate"] is not None else None
    except ValueError:
        data["tx_rate"] = None

    return WifiStats(**data)

@app.get("/api/wifi", response_model=WifiStats)
def get_wifi_stats():
    try:
        # Run the airport command
        output_bytes = subprocess.check_output(["airport", "-I"], stderr=subprocess.STDOUT)
        output = output_bytes.decode("utf-8")
    except subprocess.CalledProcessError as e:
        raise HTTPException(status_code=500, detail=f"Command failed: {e.output.decode('utf-8')}")
    except FileNotFoundError:
        raise HTTPException(status_code=500, detail="airport command not found. Ensure you are on macOS and have the command in PATH.")

    stats = parse_airport_output(output)
    return stats
