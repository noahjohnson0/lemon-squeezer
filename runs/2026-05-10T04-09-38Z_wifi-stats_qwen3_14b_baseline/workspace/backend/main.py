from fastapi import FastAPI
import subprocess
import json

app = FastAPI()

def get_wifi_info():
    try:
        result = subprocess.run([
            '/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport',
            '-I'
        ], capture_output=True, text=True, check=True)
        
        output = result.stdout
        
        lines = output.split('\n')
        
        info = {}
        for line in lines:
            if ': ' in line:
                key, value = line.split(': ', 1)
                info[key] = value
        
        return {
            'ssid': info.get('SSID', ''),
            'bssid': info.get('BSSID', ''),
            'rssi': int(info.get('RSSI', 0)),
            'channel': int(info.get('Channel', 0)),
            'tx_rate': int(info.get('Tx Rate', 0)),
            'security': info.get('Security', '')
        }
    except Exception as e:
        return {'error': str(e)}

@app.get('/api/wifi')
def get_wifi():
    return get_wifi_info()