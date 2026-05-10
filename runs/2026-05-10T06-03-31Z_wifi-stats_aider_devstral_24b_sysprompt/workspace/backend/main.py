from fastapi import FastAPI
import subprocess
import json

app = FastAPI()

def get_wifi_info():
    try:
        result = subprocess.run(['wdutil', 'info'], capture_output=True, text=True)
        wifi_data = json.loads(result.stdout)

        ssid = wifi_data.get('currentNetwork').get('SSID')
        bssid = wifi_data.get('currentNetwork').get('BSSID')
        rssi = wifi_data.get('currentNetwork').get('RSSI')
        channel = wifi_data.get('currentNetwork').get('channel')
        tx_rate = wifi_data.get('currentNetwork').get('txRateMbps')
        security = wifi_data.get('currentNetwork').get('security')

        return {
            'ssid': ssid,
            'bssid': bssid,
            'rssi': rssi,
            'channel': channel,
            'tx_rate': tx_rate,
            'security': security
        }
    except Exception as e:
        print(f"Error fetching Wi-Fi info: {e}")
        return None

@app.get("/api/wifi")
def read_wifi():
    wifi_info = get_wifi_info()
    if wifi_info:
        return wifi_info
    else:
        return {"error": "Unable to fetch Wi-Fi information"}
