from fastapi import FastAPI
import subprocess

app = FastAPI()

@app.get("/api/wifi")
async def get_wifi_stats():
    result = subprocess.run(["/usr/local/bin/wdutil", "info"], capture_output=True, text=True)
    
    stats = {
        "ssid": "",
        "bssid": "",
        "rssi": 0,
        "channel": 0,
        "tx_rate": 0,
        "security": ""
    }

    lines = result.stdout.split("\n")
    for line in lines:
        if line.startswith("Current SSID:"): stats["ssid"] = line.split(": ")[1]
        if line.startswith("BSSID:"): stats["bssid"] = line.split(": ")[1]
        if line.startswith("RSSI:"): stats["rssi"] = int(line.split(" ")[1].replace("dBm", ""))
        if line.startswith("Channel:"): stats["channel"] = int(line.split(": ")[1])
        if line.startswith("TX Rate:"): stats["tx_rate"] = int(line.split(" ")[1].replace("Mbps", ""))
        if line.startswith("Security:"): stats["security"] = line.split(": ")[1]
    
    return stats

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)