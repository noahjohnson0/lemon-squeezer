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
        # Use wdutil to get Wi-Fi information
        result = subprocess.run(
            ["wdutil", "info"],
            capture_output=True,
            text=True,
            check=True
        )
        
        # Parse the output
        output = result.stdout
        
        # Extract fields using regex
        ssid_match = re.search(r'SSID:\s+(.+)', output)
        bssid_match = re.search(r'BSSID:\s+(.+)', output)
        rssi_match = re.search(r'RSSI:\s+(-?\d+)', output)
        channel_match = re.search(r'Channel:\s+(\d+)', output)
        tx_rate_match = re.search(r'TX Rate:\s+(\d+)', output)
        security_match = re.search(r'Security:\s+(.+)', output)
        
        # Extract values or set defaults
        ssid = ssid_match.group(1).strip() if ssid_match else "Unknown"
        bssid = bssid_match.group(1).strip() if bssid_match else "Unknown"
        rssi = int(rssi_match.group(1)) if rssi_match else 0
        channel = int(channel_match.group(1)) if channel_match else 0
        tx_rate = int(tx_rate_match.group(1)) if tx_rate_match else 0
        security = security_match.group(1).strip() if security_match else "Unknown"
        
        return {
            "ssid": ssid,
            "bssid": bssid,
            "rssi": rssi,
            "channel": channel,
            "tx_rate": tx_rate,
            "security": security
        }
        
    except subprocess.CalledProcessError:
        # Fallback to system_profiler if wdutil fails
        try:
            result = subprocess.run(
                ["system_profiler", "SPAirPortDataType", "-json"],
                capture_output=True,
                text=True,
                check=True
            )
            
            data = json.loads(result.stdout)
            wifi_data = data.get("SPAirPortDataType", [{}])[0]
            
            return {
                "ssid": wifi_data.get("spairport_current_network", "Unknown"),
                "bssid": wifi_data.get("spairport_bssid", "Unknown"),
                "rssi": int(wifi_data.get("spairport_rssi", 0)),
                "channel": int(wifi_data.get("spairport_channel", 0)),
                "tx_rate": int(wifi_data.get("spairport_tx_rate", 0)),
                "security": wifi_data.get("spairport_security", "Unknown")
            }
        except:
            # If both methods fail, return default values
            return {
                "ssid": "Unknown",
                "bssid": "Unknown",
                "rssi": 0,
                "channel": 0,
                "tx_rate": 0,
                "security": "Unknown"
            }

@app.get("/")
async def root():
    return {"message": "Wi-Fi Stats API"}
