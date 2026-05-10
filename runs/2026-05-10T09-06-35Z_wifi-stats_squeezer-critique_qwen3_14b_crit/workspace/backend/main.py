from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

app = FastAPI()

# CORS configuration
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:3000"],
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/api/wifi")
async def get_wifi_info():
    import subprocess
    result = subprocess.run([
        "/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport",
        "-I"
    ], capture_output=True, text=True)

    lines = result.stdout.split("\n")
    data = {}
    for line in lines:
        if "SSID:" in line:
            data["ssid"] = line.split(" ")[1]
        elif "BSSID:" in line:
            data["bssid"] = line.split(" ")[1]
        elif "RSSI:" in line:
            data["rssi"] = int(line.split(" ")[1])
        elif "channel:" in line:
            data["channel"] = int(line.split(" ")[1])
        elif "tx_rate:" in line:
            data["tx_rate"] = int(line.split(" ")[1])
        elif "security:" in line:
            data["security"] = line.split(" ")[1]

    return data