from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from backend.utils import run_wifi_command, parse_airport_output

app = FastAPI()

@app.get("/api/wifi", response_model=WifiInfo)
async def get_wifi_info() -> WifiInfo:
    """Return current Wi-Fi connection information as JSON."""
    try:
        output = run_wifi_command("/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport -I")
        return parse_airport_output(output)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))