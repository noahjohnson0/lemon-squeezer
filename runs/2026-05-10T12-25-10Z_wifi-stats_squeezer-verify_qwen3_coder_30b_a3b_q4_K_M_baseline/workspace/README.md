# Wi-Fi Stats Dashboard

A simple Next.js + FastAPI application that displays basic Wi-Fi statistics for the current network on macOS.

## Features

- Displays Wi-Fi network information including SSID, BSSID, signal strength, channel, transmission rate, and security type
- Automatic updates every 3 seconds

## Requirements

- macOS (uses system tools like `airport` and `system_profiler`)
- Python 3.8+
- Node.js 16+

## Backend (FastAPI)

### Setup

1. Navigate to the backend directory:
   ```bash
   cd backend
   ```

2. Create a virtual environment and activate it:
   ```bash
   python -m venv venv
   source venv/bin/activate
   ```

3. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```

4. Run the server:
   ```bash
   python main.py
   ```
   
   Or using uvicorn:
   ```bash
   uvicorn main:app --host 0.0.0.0 --port 8000
   ```

The backend API will be available at `http://localhost:8000/api/wifi`

## Frontend (Next.js)

### Setup

1. Navigate to the frontend directory:
   ```bash
   cd frontend
   ```

2. Install dependencies:
   ```bash
   npm install
   ```

3. Run the development server:
   ```bash
   npm run dev
   ```

The frontend will be available at `http://localhost:3000`

## How It Works

The backend uses macOS system tools (`airport` or `system_profiler`) to gather Wi-Fi information and exposes it via a REST API endpoint. The frontend fetches this information every 3 seconds and displays it in a clean, responsive card layout.

Note: The `airport` command typically doesn't require sudo permissions for basic information, but may need elevated privileges in some restricted environments.