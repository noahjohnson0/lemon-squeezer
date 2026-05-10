import subprocess
from typing import Optional

def run_wifi_command(command: str) -> str:
    """Execute the given shell command and return its stdout as a string."""
    result = subprocess.run(
        command,
        shell=True,
        capture_output=True,
        text=True,
        check=True
    )
    return result.stdout

def parse_airport_output(output: str) -> WifiInfo:
    """Parse the raw output from the `airport -I` command into a WifiInfo instance."""
    lines = output.strip().split('\n')
    data = {}
    
    for line in lines:
        if ':' in line:
            key, value = line.split(':', 1)
            key = key.strip().lower().replace(' ', '_')
            value = value.strip()
            data[key] = value
    
    return WifiInfo(
        ssid=data.get('ssid', ''),
        bssid=data.get('bssid', ''),
        rssi=int(data.get('agrctlrssi', 0)),
        channel=data.get('currentchannel', ''),
        tx_rate=f"{data.get('agrctltxrate', '0')} Mbps",
        security=data.get('security', '')
    )