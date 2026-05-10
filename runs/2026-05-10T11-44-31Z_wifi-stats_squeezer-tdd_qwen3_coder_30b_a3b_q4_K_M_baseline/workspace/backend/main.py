from fastapi import FastAPI
from fastapi.responses import JSONResponse
import subprocess
import json
import os

app = FastAPI()

def get_wifi_info():
    """Get Wi-Fi information from macOS using airport command"""
    try:
        # Use airport -I to get current Wi-Fi info
        result = subprocess.run([
            '/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport', 
            '-I'
        ], capture_output=True, text=True, check=True)
        
        # Parse the output
        wifi_info = {}
        for line in result.stdout.split('\n'):
            if ':' in line:
                key, value = line.split(':', 1)
                wifi_info[key.strip().lower()] = value.strip()
        
        # Extract required fields
        ssid = wifi_info.get('ssid', 'N/A')
        bssid = wifi_info.get('bssid', 'N/A')
        rssi = wifi_info.get('rssi', 'N/A')
        channel = wifi_info.get('channel', 'N/A')
        tx_rate = wifi_info.get('txrate', 'N/A')
        security = wifi_info.get('security', 'N/A')
        
        return {
            "ssid": ssid,
            "bssid": bssid,
            "rssi": rssi,
            "channel": channel,
            "tx_rate": tx_rate,
            "security": security
        }
    except subprocess.CalledProcessError:
        # Fallback to system_profiler if airport fails
        try:
            result = subprocess.run([
                'system_profiler', 'SPAirPortDataType'
            ], capture_output=True, text=True, check=True)
            
            # Parse system_profiler output
            lines = result.stdout.split('\n')
            wifi_info = {}
            for line in lines:
                if ':' in line:
                    key, value = line.split(':', 1)
                    wifi_info[key.strip().lower()] = value.strip()
            
            ssid = wifi_info.get('ssid', 'N/A')
            bssid = wifi_info.get('bssid', 'N/A')
            rssi = wifi_info.get('rssi', 'N/A')
            channel = wifi_info.get('channel', 'N/A')
            tx_rate = wifi_info.get('txrate', 'N/A')
            security = wifi_info.get('security', 'N/A')
            
            return {
                "ssid": ssid,
                "bssid": bssid,
                "rssi": rssi,
                "channel": channel,
                "tx_rate": tx_rate,
                "security": security
            }
        except Exception:
            return {
                "ssid": "Unknown",
                "bssid": "Unknown", 
                "rssi": "Unknown",
                "channel": "Unknown",
                "tx_rate": "Unknown",
                "security": "Unknown"
            }

@app.get("/api/wifi")
async def get_wifi_stats():
    wifi_data = get_wifi_info()
    return JSONResponse(content=wifi_data)

@app.get("/")
async def root():
    return {"message": "WiFi Stats API - Use /api/wifi endpoint"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)