from fastapi import FastAPI
import subprocess

app = FastAPI()

@app.get("/api/wifi")
async def get_wifi_stats():
    result = subprocess.run(['/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport', '-I'], capture_output=True, text=True)
    output = result.stdout

    wifi_stats = {
        "ssid": None,
        "bssid": None,
        "rssi": None,
        "channel": None,
        "tx_rate": None,
        "security": None
    }

    for line in output.splitlines():
        if line.startswith(" SSID:"):
            wifi_stats["ssid"] = line.split(":")[1].strip()
        elif line.startswith(" BSSID:"):
            wifi_stats["bssid"] = line.split(":")[1].strip()
        elif line.startswith(" RSSI:"):
            wifi_stats["rssi"] = int(line.split(":")[1].split()[0])
        elif line.startswith(" CHANNEL:"):
            wifi_stats["channel"] = int(line.split(":")[1].split()[0])
        elif line.startswith(" TXMCS:"):
            tx_rate = line.split(":")[1].strip()
            if tx_rate.isdigit():
                wifi_stats["tx_rate"] = float(tx_rate) * 2.5
        elif line.startswith(" SECURITY:"):
            wifi_stats["security"] = line.split(":")[1].strip()

    return wifi_stats

