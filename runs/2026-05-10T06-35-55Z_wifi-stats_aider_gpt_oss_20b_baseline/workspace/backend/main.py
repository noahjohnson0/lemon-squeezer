from fastapi import FastAPI
import subprocess

app = FastAPI()

def get_wifi_info():
    """
    Uses the macOS `airport -I` command to retrieve Wi‑Fi information.
    Returns a dictionary with the required fields.
    """
    try:
        result = subprocess.run(
            ["/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport", "-I"],
            capture_output=True,
            text=True,
            check=True
        )
        output = result.stdout
        info = {}
        for line in output.splitlines():
            if ':' in line:
                key, value = line.split(':', 1)
                info[key.strip()] = value.strip()

        ssid = info.get("SSID")
        bssid = info.get("BSSID")
        rssi = int(info.get("agrCtlRSSI", "0"))
        channel = info.get("channel")
        tx_rate = info.get("agrCtlTxRate")
        security = info.get("security")

        return {
            "ssid": ssid,
            "bssid": bssid,
            "rssi": rssi,
            "channel": channel,
            "tx_rate": tx_rate,
            "security": security,
        }
    except Exception as e:
        return {"error": str(e)}

@app.get("/api/wifi")
async def wifi():
    """
    GET /api/wifi
    Returns JSON with ssid, bssid, rssi, channel, tx_rate, security.
    """
    return get_wifi_info()
