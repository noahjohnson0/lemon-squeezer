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
        # Try using system_profiler first
        result = subprocess.run(
            ["system_profiler", "SPAirPortDataType"],
            capture_output=True,
            text=True,
            check=True
        )
        
        # Parse the output to extract Wi-Fi information
        output = result.stdout
        
        # Extract SSID
        ssid_match = re.search(r'SSID: (.+)', output)
        ssid = ssid_match.group(1).strip() if ssid_match else "Unknown"
        
        # Extract BSSID
        bssid_match = re.search(r'BSSID: (.+)', output)
        bssid = bssid_match.group(1).strip() if bssid_match else "Unknown"
        
        # Extract RSSI
        rssi_match = re.search(r'RSSI: (.+)', output)
        rssi = rssi_match.group(1).strip() if rssi_match else "Unknown"
        
        # Extract Channel
        channel_match = re.search(r'Channel: (.+)', output)
        channel = channel_match.group(1).strip() if channel_match else "Unknown"
        
        # Extract TX Rate
        tx_rate_match = re.search(r'TX Rate: (.+)', output)
        tx_rate = tx_rate_match.group(1).strip() if tx_rate_match else "Unknown"
        
        # Extract Security
        security_match = re.search(r'Security: (.+)', output)
        security = security_match.group(1).strip() if security_match else "Unknown"
        
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
            "error": f"Failed to fetch Wi-Fi info: {str(e)}"
        }
    except Exception as e:
        return {
            "error": f"An error occurred: {str(e)}"
        }

@app.get("/")
async def root():
    return {"message": "Wi-Fi Stats API"}
