from fastapi import FastAPI
from pydantic import BaseModel
from backend.utils.wifi_info import get_wifi_info

app = FastAPI(title="Wi-Fi Stats API", version="1.0.0")

class WifiStatResponse(BaseModel):
    ssid: str | None
    bssid: str | None
    rssi: int | None
    channel: int | None
    tx_rate: int | None
    security: str

@app.get("/api/wifi", response_model=WifiStatResponse)
async def read_wifi() -> WifiStatResponse:
    wifi_data = get_wifi_info()
    return WifiStatResponse(**wifi_data)

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="127.0.0.1", port=8000)