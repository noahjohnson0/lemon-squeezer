from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
import subprocess

app = FastAPI()

# Allow CORS for frontend
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:3000"],
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/api/wifi")
async def get_wifi_stats():
    try:
        # Use wdutil info to get Wi-Fi stats
        result = subprocess.run(
            ["wdutil", "info"],
            capture_output=True,
            text=True,
            check=True
        )
        
        # Parse output
        lines = result.stdout.splitlines()
        stats = {}
        
        for line in lines:
            if line.startswith("SSID: "):
                stats["ssid"] = line.split(": ")[1]
            elif line.startswith("BSSID: "):
                stats["bssid"] = line.split(": ")[1]
            elif line.startswith("RSSI: "):
                stats["rssi"] = int(line.split(": ")[1])
            elif line.startswith("Channel: "):
                stats["channel"] = int(line.split(": ")[1])
            elif line.startswith("Tx Rate: "):
                stats["tx_rate"] = float(line.split(": ")[1].split(" ")[0])
            elif line.startswith("Security: "):
                stats["security"] = line.split(": ")[1]
        
        return stats
    
    except Exception as e:
        return {"error": str(e)}
