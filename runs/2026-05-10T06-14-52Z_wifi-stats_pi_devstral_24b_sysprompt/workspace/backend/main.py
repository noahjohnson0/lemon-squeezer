from fastapi import FastAPI, HTTPException
import subprocess
import json

app = FastAPI()

@app.get("/api/wifi")
def get_wifi_stats():
    try:
        # Run system_profiler to get WiFi information in JSON format
        result = subprocess.run(
            ['system_profiler', 'SPWiFiDataType', '-json'],
            capture_output=True,
            check=True,
            text=True
        )
        data = json.loads(result.stdout)
    
        if not data['SPWiFiDataType']:
            raise HTTPException(status_code=404, detail="No Wi-Fi data found")
    
        wifi_info = data['SPWiFiDataType'][0]
        return {
            'ssid': wifi_info.get('BSSID'),
            'bssid': wifi_info.get('BSSID'),
            'rssi': wifi_info.get('SignalStrength'),  # In percentage, need to convert to dBm
            'channel': wifi_info.get('Channel'),
            'tx_rate': None,  # Not available in system_profiler output
            'security': wifi_info.get('Security')
        }
    except subprocess.CalledProcessError as e:
        raise HTTPException(status_code=500, detail=str(e))