from fastapi import FastAPI
import subprocess

app = FastAPI()

def get_wifi_info():
    try:
        result = subprocess.run(
            ['/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport', '-I'],
            capture_output=True,
            text=True,
            check=True
        )
        output = result.stdout
        lines = output.split('\n')
        
        ssid = next(line.split(': ')[1] for line in lines if line.startswith('SSID: '))
        bssid = next(line.split(': ')[1] for line in lines if line.startswith('BSSID: '))
        rssi = int(next(line.split(': ')[1] for line in lines if line.startswith('RSSI: ')))
        channel = int(next(line.split(': ')[1] for line in lines if line.startswith('Channel: ')))
        tx_rate = int(next(line.split(': ')[1] for line in lines if line.startswith('Tx Rate: ')))
        security = next(line.split(': ')[1] for line in lines if line.startswith('Security: '))
        
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

@app.get("/api/wifi")
async def get_wifi():
    return get_wifi_info()
