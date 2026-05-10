from fastapi import FastAPI
import subprocess

app = FastAPI()

@app.get("/api/wifi")
async def get_wifi_stats():
    try:
        result = subprocess.check_output(["/usr/sbin/wdutil", "info"], stderr=subprocess.STDOUT, text=True)
        lines = result.split("\n")

        ssid = next(line.split(": ")[1] for line in lines if line.startswith("SSID"))
        bssid = next(line.split(": ")[1] for line in lines if line.startswith("BSSID"))
        rssi = int(next(line.split(": ")[1] for line in lines if line.startswith("RSSI")))
        channel = int(next(line.split(": ")[1] for line in lines if line.startswith("Channel")))
        tx_rate = int(next(line.split(": ")[1] for line in lines if line.startswith("Tx rate")))
        security = next(line.split(": ")[1] for line in lines if line.startswith("Security"))

        return {
            "ssid": ssid,
            "bssid": bssid,
            "rssi": rssi,
            "channel": channel,
            "tx_rate": tx_rate,
            "security": security
        }
    except Exception as e:
        return {"error": str(e)}