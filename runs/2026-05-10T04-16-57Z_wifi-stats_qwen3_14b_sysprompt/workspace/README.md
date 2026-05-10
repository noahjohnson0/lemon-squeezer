# Wi-Fi Stats App

This app displays Wi-Fi network statistics on macOS using FastAPI and Next.js.

## Structure
- `backend/` - Python FastAPI backend
- `frontend/` - Next.js frontend

## Requirements
- Python 3.10+
- Node.js 18+

## Run Instructions
1. Backend:
   ```bash
   cd backend
   uvicorn main:app --reload
   ```

2. Frontend:
   ```bash
   cd frontend
   npm install
   npm run dev
   ```

Visit http://localhost:3000 in your browser.