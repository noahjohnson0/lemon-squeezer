from fastapi import FastAPI
import subprocess
import re

app = FastAPI()

@app.get("/api/wifi")
async def get_wifi_stats():
    try:
        result = subprocess.run([
            "/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport",
            "-I"
        ], capture_output=True, text=True, check=True)
        
        output = result.stdout
        
        # Parse output
        stats = {
            "ssid": re.search("SSID: ([^
]*)", output).group(1),
            "bssid": re.search("BSSID: ([^
]*)", output).group(1),
            "rssi": int(re.search("RSSI: (-?\d+)", output).group(1)),
            "channel": int(re.search("Channel: (\d+)", output).group(1)),
            "tx_rate": int(re.search("Tx rate: (\d+)\s+Mbps", output).group(1)),
            "security": re.search("Security: ([^
]*)", output).group(1)
        }
        
        return stats
    except Exception as e:
        return {"error": str(e)}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)