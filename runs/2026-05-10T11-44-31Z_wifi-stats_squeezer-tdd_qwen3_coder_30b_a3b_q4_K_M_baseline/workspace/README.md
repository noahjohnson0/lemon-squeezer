# Wi-Fi Stats Dashboard

A Next.js + FastAPI application that displays real-time Wi-Fi network statistics on macOS.

## Features
- Displays SSID, BSSID, RSSI, channel, tx rate, and security info
- Auto-refreshes every 3 seconds
- Clean, responsive card-based UI
- Fallback mechanisms for network data retrieval

## Project Structure
```
.
├── backend/
│   ├── main.py          # FastAPI server with /api/wifi endpoint
│   └── requirements.txt # Python dependencies
├── frontend/
│   ├── app/             # Next.js App Router pages
│   ├── package.json     # Node.js dependencies
│   └── app/globals.css  # Global CSS styles
└── README.md            # This file
```

## Setup Instructions

### Prerequisites
- Python 3.7+
- Node.js 16+

### Backend Setup (FastAPI)
1. Navigate to the backend directory:
   ```bash
   cd backend
   ```

2. Install Python dependencies:
   ```bash
   pip install -r requirements.txt
   ```

3. Run the FastAPI server:
   ```bash
   python main.py
   ```

   Or with uvicorn:
   ```bash
   uvicorn main:app --reload
   ```

   The API will be available at `http://localhost:8000/api/wifi`

### Frontend Setup (Next.js)
1. Navigate to the frontend directory:
   ```bash
   cd frontend
   ```

2. Install Node.js dependencies:
   ```bash
   npm install
   ```

3. Run the Next.js development server:
   ```bash
   npm run dev
   ```

   The frontend will be available at `http://localhost:3000`

## Usage
1. Start both the backend and frontend servers
2. Visit `http://localhost:3000` in your browser
3. The dashboard will automatically fetch and display Wi-Fi statistics every 3 seconds

## API Endpoints
- `GET /api/wifi` - Get current Wi-Fi network statistics

## Security Note
This application is designed for local network use only. It accesses macOS network utilities directly and does not require any authentication.

## Troubleshooting
- If you encounter CORS issues, make sure both servers are running on the same host
- The application requires network access to retrieve Wi-Fi information
- If `fetch` fails, check that the backend is running and accessible at `http://localhost:8000/api/wifi`