from fastapi import FastAPI
import subprocess

app = FastAPI()

@app.get("/api/wifi")
def get_wifi_info():
    result = subprocess.run(["/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport", "-I"], stdout=subprocess.PIPE)
    output = result.stdout.decode().strip()
    
    wifi_info = {}
    for line in output.splitlines():
        key, value = line.strip().split(': ', 1)
        wifi_info[key] = value
    
    return {
        "ssid": wifi_info.get("SSID"),
        "bssid": wifi_info.get("BSSID"),
        "rssi": int(wifi_info.get("RSSI")),
        "channel": int(wifi_info.get("CHANNEL")),
        "tx_rate": float(wifi_info.get("txrate").split()[0]),
        "security": wifi_info.get("authmode")
    }
