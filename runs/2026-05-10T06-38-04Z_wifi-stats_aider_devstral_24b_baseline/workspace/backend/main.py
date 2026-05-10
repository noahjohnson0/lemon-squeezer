from fastapi import FastAPI
import subprocess
import json

app = FastAPI()

def get_wifi_info():
    try:
        result = subprocess.run(['/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport', '-I'], capture_output=True, text=True)
        if result.returncode == 0:
            info = {}
            for line in result.stdout.splitlines():
                key, value = line.split(': ', 1)
                info[key] = value
            return {
                "ssid": info.get("SSID", ""),
                "bssid": info.get("BSSID", ""),
                "rssi": int(info.get("agrCtlRSSI", 0)),
                "channel": int(info.get("channel", 0)),
                "tx_rate": float(info.get("lastTxRate", 0.0)),
                "security": info.get("security", "")
            }
    except Exception as e:
        print(f"Error: {e}")
    return {}

@app.get("/api/wifi")
def read_wifi():
    wifi_info = get_wifi_info()
    return json.dumps(wifi_info)
