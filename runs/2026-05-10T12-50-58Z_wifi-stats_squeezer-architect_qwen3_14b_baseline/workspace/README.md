# Wi-Fi Stats Application

## Installation

1. Ensure you're on a macOS environment
2. Install dependencies:
   ```bash
   npm install
   ```

## Running the Servers

1. Start the backend:
   ```bash
   cd backend
   uvicorn main:app --reload
   ```

2. Start the frontend:
   ```bash
   cd frontend
   npm run dev
   ```

## Example Output

When connected to a Wi-Fi network, you'll see output similar to:

```
SSID: MyNetwork
BSSID: 00:11:22:33:44:55
Signal: -65 dBm
Channel: 6
Speed: 650 Mbps
Security: WPA2
```

## Troubleshooting

1. If you get `Command not found` errors:
   - Ensure the airport command is available in your PATH
   - Try using absolute path: `/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport -I`

2. For permission issues:
   - Run the backend with elevated privileges if needed

3. To test the API directly:
   ```bash
   curl http://localhost:8000/api/wifi
   ```