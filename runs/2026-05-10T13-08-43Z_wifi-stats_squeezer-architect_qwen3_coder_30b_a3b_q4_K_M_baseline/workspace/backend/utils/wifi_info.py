import subprocess
import re
import logging

def get_wifi_info() -> dict:
    """
    Get Wi-Fi information from macOS using airport command.
    Returns a dictionary with ssid, bssid, rssi, channel, tx_rate, security.
    """
    try:
        # Use airport -I command to get Wi-Fi info
        result = subprocess.run(
            ['/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport', '-I'],
            capture_output=True,
            text=True,
            timeout=10
        )
        
        if result.returncode != 0:
            logging.error(f"Airport command failed: {result.stderr}")
            return {
                "ssid": None,
                "bssid": None,
                "rssi": None,
                "channel": None,
                "tx_rate": None,
                "security": "Not connected"
            }
        
        output = result.stdout
        
        # Parse the output
        wifi_info = {
            "ssid": None,
            "bssid": None,
            "rssi": None,
            "channel": None,
            "tx_rate": None,
            "security": None
        }
        
        for line in output.split('\n'):
            line = line.strip()
            if line.startswith('SSID:'):
                wifi_info["ssid"] = line.split(':', 1)[1].strip()
            elif line.startswith('BSSID:'):
                wifi_info["bssid"] = line.split(':', 1)[1].strip()
            elif line.startswith('RSSI:'):
                wifi_info["rssi"] = int(line.split(':', 1)[1].strip())
            elif line.startswith('channel:'):
                wifi_info["channel"] = int(line.split(':', 1)[1].strip())
            elif line.startswith('tx rate:'):
                # Extract Mbps value after "tx rate:"
                tx_rate_match = re.search(r'tx rate:\s*(\d+)', line)
                if tx_rate_match:
                    wifi_info["tx_rate"] = int(tx_rate_match.group(1))
            elif line.startswith('security:'):
                wifi_info["security"] = line.split(':', 1)[1].strip()
        
        # If no SSID, consider it not connected
        if wifi_info["ssid"] is None:
            wifi_info["security"] = "Not connected"
            
        return wifi_info
        
    except subprocess.TimeoutExpired:
        logging.error("Airport command timed out")
        return {
            "ssid": None,
            "bssid": None,
            "rssi": None,
            "channel": None,
            "tx_rate": None,
            "security": "Not connected"
        }
    except FileNotFoundError:
        logging.error("Airport command not found")
        
        # Fallback to system_profiler if airport is not available
        try:
            result = subprocess.run(
                ['system_profiler', 'SPAirPortDataType'],
                capture_output=True,
                text=True,
                timeout=10
            )
            
            if result.returncode != 0:
                logging.error(f"System profiler failed: {result.stderr}")
                return {
                    "ssid": None,
                    "bssid": None,
                    "rssi": None,
                    "channel": None,
                    "tx_rate": None,
                    "security": "Not connected"
                }
                
            output = result.stdout
            
            wifi_info = {
                "ssid": None,
                "bssid": None,
                "rssi": None,
                "channel": None,
                "tx_rate": None,
                "security": "Not connected"
            }
            
            # Parse system_profiler output
            for line in output.split('\n'):
                line = line.strip()
                if line.startswith('Network Name:'):
                    wifi_info["ssid"] = line.split(':', 1)[1].strip()
                elif line.startswith('BSSID:'):
                    wifi_info["bssid"] = line.split(':', 1)[1].strip()
                elif line.startswith('Channel:'):
                    wifi_info["channel"] = int(line.split(':', 1)[1].strip())
                elif line.startswith('Security:'):
                    wifi_info["security"] = line.split(':', 1)[1].strip()
            
            return wifi_info
            
        except Exception:
            logging.error("Both airport and system_profiler commands failed")
            return {
                "ssid": None,
                "bssid": None,
                "rssi": None,
                "channel": None,
                "tx_rate": None,
                "security": "Not connected"
            }
    except Exception as e:
        logging.error(f"Unexpected error in get_wifi_info: {str(e)}")
        return {
            "ssid": None,
            "bssid": None,
            "rssi": None,
            "channel": None,
            "tx_rate": None,
            "security": "Not connected"
        }