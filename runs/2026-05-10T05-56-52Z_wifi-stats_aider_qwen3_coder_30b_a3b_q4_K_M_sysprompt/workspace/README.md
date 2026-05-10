# Wi-Fi Stats App

A Next.js frontend with a FastAPI backend that displays Wi-Fi network information on macOS.

## Requirements

- Python 3.7+
- Node.js 16+
- macOS (with `wdutil` or `system_profiler` available)

## Backend Setup

1. Navigate to the backend directory:
   ```
   cd backend
   ```

2. Install dependencies:
   ```
   pip install -r requirements.txt
   ```

3. Run the FastAPI server:
   ```
   uvicorn main:app --reload --host 0.0.0.0 --port 8000
   ```

## Frontend Setup

1. Navigate to the frontend directory:
   ```
   cd frontend
   ```

2. Install dependencies:
   ```
   npm install
   ```

3. Run the Next.js development server:
   ```
   npm run dev
   ```

## Usage

1. Start both servers (backend and frontend)
2. Open your browser to `http://localhost:3000`
3. The app will automatically fetch Wi-Fi information every 3 seconds
4. The information displayed includes:
   - SSID (network name)
   - BSSID (MAC address)
   - RSSI (signal strength in dBm)
   - Channel
   - TX Rate (transmission rate in Mbps)
   - Security type

## Notes

- The backend uses `wdutil info` command by default, falling back to `system_profiler` if needed
- On macOS, the app requires no sudo privileges for basic Wi-Fi information
- The frontend uses Next.js App Router with client-side data fetching
- CORS is enabled in the backend to allow frontend requests
