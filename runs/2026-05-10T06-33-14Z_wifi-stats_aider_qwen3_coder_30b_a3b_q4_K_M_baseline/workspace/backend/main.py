from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
import subprocess
import json
import re

app = FastAPI()

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/api/wifi")
async def get_wifi_info():
    try:
        # Use airport command to get Wi-Fi info
        result = subprocess.run(
            ["/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport", "-I"],
            capture_output=True,
            text=True,
            check=True
        )
        
        # Parse the output
        wifi_info = {}
        for line in result.stdout.split('\n'):
            if ':' in line:
                key, value = line.split(':', 1)
                wifi_info[key.strip()] = value.strip()
        
        # Extract required fields
        ssid = wifi_info.get("SSID", "Unknown")
        bssid = wifi_info.get("BSSID", "Unknown")
        rssi = wifi_info.get("RSSI", "Unknown")
        channel = wifi_info.get("Channel", "Unknown")
        tx_rate = wifi_info.get("TX Rate", "Unknown")
        security = wifi_info.get("Security", "Unknown")
        
        # Convert RSSI to dBm if possible
        if rssi != "Unknown":
            try:
                rssi = int(rssi)
            except ValueError:
                rssi = "Unknown"
        
        # Convert TX Rate to Mbps if possible
        if tx_rate != "Unknown":
            try:
                # Extract numeric value from "XX.X Mbps" format
                tx_rate_match = re.search(r'(\d+\.?\d*)\s*Mbps', tx_rate)
                if tx_rate_match:
                    tx_rate = float(tx_rate_match.group(1))
                else:
                    tx_rate = "Unknown"
            except ValueError:
                tx_rate = "Unknown"
        
        return {
            "ssid": ssid,
            "bssid": bssid,
            "rssi": rssi,
            "channel": channel,
            "tx_rate": tx_rate,
            "security": security
        }
        
    except subprocess.CalledProcessError as e:
        return {
            "error": f"Failed to get Wi-Fi info: {str(e)}"
        }
    except Exception as e:
        return {
            "error": f"An error occurred: {str(e)}"
        }

@app.get("/")
async def root():
    return {"message": "Wi-Fi Stats API"}
