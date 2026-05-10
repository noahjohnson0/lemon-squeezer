from fastapi import FastAPI
import subprocess
import json

app = FastAPI()

@app.get("/api/wifi")
async def get_wifi_stats():
    try:
        # Use airport command to get WiFi info
        result = subprocess.run([
            "/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport",
            "-I"
        ],
        capture_output=True,
        text=True,
        check=True)

        # Parse output
        lines = result.stdout.splitlines()
        data = {}
        for line in lines:
            if ": " in line:
                key, value = line.split(": ", 1)
                data[key] = value

        # Extract required fields
        return {
            "ssid": data.get("SSID", "Unknown"),
            "bssid": data.get("BSSID", "Unknown"),
            "rssi": data.get("RSSI", "Unknown"),
            "channel": data.get("Channel", "Unknown"),
            "tx_rate": data.get("TXRate", "Unknown"),
            "security": data.get("Security", "Unknown")
        }
    except Exception as e:
        return {
            "error": str(e)
        }