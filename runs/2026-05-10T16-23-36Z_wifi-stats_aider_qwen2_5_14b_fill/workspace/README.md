# Wi-Fi Stats App

This project is a small Next.js + Python (FastAPI) app that displays basic Wi-Fi stats about the user's current network on macOS.

## Setup Instructions

### Backend (Python FastAPI)

1. Navigate to `backend/` directory.
2. Install dependencies: `pip install fastapi uvicorn`.
3. Start the server: `uvicorn backend.api:app --reload`.

### Frontend (Next.js)

1. Navigate to `frontend/` directory.
2. Install dependencies: `npm install`.
3. Start the development server: `npm run dev`.

## Usage

- Open your browser and navigate to `http://localhost:3000`.
- The app will fetch Wi-Fi stats every 3 seconds and display them in a clean card layout.

