# Wi-Fi Stats App

A Next.js + FastAPI application that displays basic Wi-Fi statistics about the user's current network on macOS.

## Features

- Displays SSID, BSSID, RSSI, channel, transmit rate, and security information
- Automatically refreshes every 3 seconds
- Clean, responsive card-based layout

## Requirements

- macOS (for system_profiler command)
- Python 3.7+
- Node.js 16+

## Setup

### Backend (Python/FastAPI)

1. Navigate to the backend directory:
   ```
   cd backend
   ```

2. Install dependencies:
   ```
   pip install -r requirements.txt
   ```

3. Run the backend server:
   ```
   uvicorn main:app --reload
   ```

### Frontend (Next.js)

1. Navigate to the frontend directory:
   ```
   cd frontend
   ```

2. Install dependencies:
   ```
   npm install
   ```

3. Run the development server:
   ```
   npm run dev
   ```

## Usage

1. Start both the backend and frontend servers
2. Open your browser and navigate to `http://localhost:3000`
3. The page will automatically fetch and display Wi-Fi information every 3 seconds

## API Endpoint

The backend provides a single endpoint:
- `GET /api/wifi` - Returns Wi-Fi information in JSON format

## Notes

- This application uses `system_profiler SPAirPortDataType` to fetch Wi-Fi information
- The frontend uses relative URLs to communicate with the backend
- The backend server must be running for the frontend to fetch data
