# Wi-Fi Stats App

A simple app that displays Wi-Fi network statistics on macOS using FastAPI and Next.js.

## Structure
- `backend/`: Python FastAPI server
- `frontend/`: Next.js frontend application

## Requirements
- Python 3.10+
- Node.js 18+

## Run Instructions

### 1. Python Backend
1. Navigate to `backend/`
2. Run the server:
   ```bash
   uvicorn main:app --reload
   ```
3. The API will be available at http://localhost:8000/api/wifi

### 2. Next.js Frontend
1. Navigate to `frontend/`
2. Run the development server:
   ```bash
   npm run dev
   ```
3. The app will be available at http://localhost:3000

Note: The backend and frontend should run on separate ports (8000 and 3000 respectively).