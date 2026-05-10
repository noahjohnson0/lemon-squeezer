from pydantic import BaseModel

class WifiInfo(BaseModel):
    ssid: str
    bssid: str
    rssi: int
    channel: str
    tx_rate: str
    security: str