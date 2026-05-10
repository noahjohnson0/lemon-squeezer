from fastapi import FastAPI
from pydantic import BaseModel
import subprocess
import json
from typing import Optional

app = FastAPI()

class WifiInfo(BaseModel):
    ssid: Optional[str] = None
    bssid: Optional[str] = None
    rssi: Optional[int] = None
    channel: Optional[int] = None
    tx_rate: Optional[float] = None
    security: Optional[str] = None

def get_wifi_info():
    try:
        # Try using wdutil first (modern macOS)
        result = subprocess.run(['wdutil', 'info'], capture_output=True, text=True, timeout=10)
        if result.returncode == 0:
            info = result.stdout
            # Parse wdutil output
            wifi_data = {}
            for line in info.split('\n'):
                if ': ' in line:
                    key, value = line.split(': ', 1)
                    if key == 'SSID':
                        wifi_data['ssid'] = value
                    elif key == 'BSSID':
                        wifi_data['bssid'] = value
                    elif key == 'RSSI':
                        wifi_data['rssi'] = int(value)
                    elif key == 'Channel':
                        wifi_data['channel'] = int(value)
                    elif key == 'Tx Rate':
                        # Extract Mbps from "Tx Rate: 150.000000 MBit/s"
                        tx_rate_str = value.split()[0]
                        wifi_data['tx_rate'] = float(tx_rate_str)
                    elif key == 'Security':
                        wifi_data['security'] = value
            return wifi_data
        else:
            # Fallback to system_profiler
            result = subprocess.run(
                ['system_profiler', 'SPAirPortDataType', '-json'], 
                capture_output=True, text=True, timeout=10
            )
            if result.returncode == 0:
                data = json.loads(result.stdout)
                if 'SPAirPortDataType' in data:
                    airport_data = data['SPAirPortDataType'][0]
                    wifi_data = {
                        'ssid': airport_data.get('spairport_current_network', ''),
                        'bssid': airport_data.get('spairport_bssid', ''),
                        'rssi': int(airport_data.get('spairport_rssi', 0)),
                        'channel': int(airport_data.get('spairport_channel', 0)),
                        'tx_rate': float(airport_data.get('spairport_tx_rate', 0)),
                        'security': airport_data.get('spairport_security', '')
                    }
                    return wifi_data
    except Exception as e:
        print(f"Error getting Wi-Fi info: {e}")
        return {}

@app.get("/api/wifi", response_model=WifiInfo)
async def get_wifi():
    wifi_data = get_wifi_info()
    return WifiInfo(**wifi_data)

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="127.0.0.1", port=8000)