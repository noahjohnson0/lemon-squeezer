from fastapi import FastAPI
import subprocess

app = FastAPI()

@app.get("/api/wifi")
async def get_wifi_stats():
    try:
        # Run airport command to get Wi-Fi info
        result = subprocess.run([
            "/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport",
            "-I"
        ], capture_output=True, text=True, check=True)

        # Parse output
        output = result.stdout
        stats = {}
        
        for line in output.splitlines():
            if line.startswith("SSID:"): stats["ssid"] = line.split(" ")[1]
            if line.startswith("BSSID:"): stats["bssid"] = line.split(" ")[1]
            if line.startswith("RSSI:"): stats["rssi"] = int(line.split(" ")[1])
            if line.startswith("channel:"): stats["channel"] = int(line.split(" ")[1])
            if line.startswith("tx rate:"): stats["tx_rate"] = int(line.split(" ")[2])
            if line.startswith("Security:"): stats["security"] = line.split(" ")[1]
        
        return stats
    except Exception as e:
        return {"error": str(e)}