Build a small Next.js + Python (FastAPI) app that displays basic Wi-Fi stats about the user's current network on macOS. Requirements:
1. Python backend (FastAPI in backend/) with one endpoint GET /api/wifi that returns JSON with: ssid, bssid, rssi (signal strength dBm), channel, tx_rate (Mbps), security. On macOS use the 'wdutil info' command (sudo not required for basic info) or 'system_profiler SPAirPortDataType' or '/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport -I'.
2. Next.js frontend (App Router) in frontend/ with one page that fetches /api/wifi every 3 seconds and displays the stats in a clean card layout.
3. A README.md at the root with run instructions for both servers.
Create all files yourself using the write/edit tools. Do not run npm install or start servers. Just create the code.
