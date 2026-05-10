# Wi-Fi Stats Dashboard

A Next.js + FastAPI application that displays real-time Wi-Fi network statistics on macOS.

## Features

- Displays SSID, BSSID, signal strength (dBm), channel, TX rate (Mbps), and security information
- Auto-refreshes every 3 seconds
- Clean, responsive card-based UI
- Error handling for network issues

## Requirements

- macOS (uses system commands)
- Python 3.7+
- Node.js 16+

## Setup

### Backend (FastAPI)

1. Navigate to the backend directory:
   ```
   cd backend
   ```

2. Create a virtual environment:
   ```
   python -m venv venv
   source venv/bin/activate
   ```

3. Install dependencies:
   ```
   pip install -r requirements.txt
   ```

4. Run the backend server:
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

1. Start both servers (backend and frontend)
2. Open your browser to `http://localhost:3000`
3. The dashboard will automatically fetch and display Wi-Fi information every 3 seconds

## API Endpoint

The backend provides a single endpoint:
- `GET /api/wifi` - Returns Wi-Fi network information in JSON format

## Notes

- The application uses system commands (`airport -I`) to fetch Wi-Fi information
- No sudo privileges required for basic information
- The frontend automatically refreshes every 3 seconds
- Error handling is included for network issues or command failures
