from fastapi import FastAPI
from pydantic import BaseModel
import subprocess
import json
import re

app = FastAPI()

class WiFiStats(BaseModel):
    ssid: str
    bssid: str
    rssi: int
    channel: int
    tx_rate: float
    security: str

def get_wifi_stats():
    """Get Wi-Fi stats using airport command on macOS"""
    try:
        # Run airport command to get Wi-Fi info
        result = subprocess.run([
            "/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport", 
            "-I"
        ], capture_output=True, text=True, check=True)
        
        # Parse the output
        info = {}
        for line in result.stdout.strip().split('\n'):
            if ':' in line:
                key, value = line.split(':', 1)
                info[key.strip()] = value.strip()
        
        # Extract required fields
        ssid = info.get('SSID', 'Unknown')
        bssid = info.get('BSSID', 'Unknown')
        rssi = int(info.get('agrCtlRSSI', 0))
        channel = int(info.get('channel', 0))
        tx_rate = float(info.get('lastTxRate', 0))
        security = info.get('security', 'Unknown')
        
        return WiFiStats(
            ssid=ssid,
            bssid=bssid,
            rssi=rssi,
            channel=channel,
            tx_rate=tx_rate,
            security=security
        )
    except Exception as e:
        # If airport command fails, try system_profiler as fallback
        try:
            result = subprocess.run([
                "system_profiler", "SPAirPortDataType"
            ], capture_output=True, text=True, check=True)
            
            # Parse system_profiler output
            info = {}
            for line in result.stdout.strip().split('\n'):
                if ':' in line:
                    key, value = line.split(':', 1)
                    info[key.strip()] = value.strip()
            
            # Extract required fields
            ssid = info.get('SSID', 'Unknown')
            bssid = info.get('BSSID', 'Unknown')
            rssi = int(info.get('Signal Noise Ratio', '0').split(' ')[0] if 'Signal Noise Ratio' in info else 0)
            channel = int(info.get('Channel', '0'))
            tx_rate = 0.0  # Not available from system_profiler
            security = info.get('Security', 'Unknown')
            
            return WiFiStats(
                ssid=ssid,
                bssid=bssid,
                rssi=rssi,
                channel=channel,
                tx_rate=tx_rate,
                security=security
            )
        except Exception:
            # Return default stats if both methods fail
            return WiFiStats(
                ssid="Unknown",
                bssid="Unknown",
                rssi=0,
                channel=0,
                tx_rate=0.0,
                security="Unknown"
            )

@app.get("/api/wifi", response_model=WiFiStats)
async def get_wifi():
    return get_wifi_stats()

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)