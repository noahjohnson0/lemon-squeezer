from fastapi import FastAPI
import subprocess
import re
import json

app = FastAPI()

def get_wifi_info():
    try:
        # Run the airport command to get Wi-Fi info
        result = subprocess.check_output(
            ['/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport', '-I'],
            stderr=subprocess.STDOUT,
            text=True
        )
        
        # Parse the output
        info = {}
        for line in result.split('\n'):
            if ': ' in line:
                key, value = line.split(': ', 1)
                info[key.strip()] = value.strip()
        
        # Extract required fields
        wifi_data = {
            "ssid": info.get("SSID", ""),
            "bssid": info.get("BSSID", ""),
            "rssi": info.get("RSSI", "N/A"),
            "channel": info.get("Channel", "N/A"),
            "tx_rate": info.get("TX Rate", "N/A"),
            "security": info.get("Security", "N/A")
        }
        
        return wifi_data
    
    except Exception as e:
        return {"error": str(e)}

@app.get("/api/wifi")
async def get_wifi():
    return get_wifi_info()
