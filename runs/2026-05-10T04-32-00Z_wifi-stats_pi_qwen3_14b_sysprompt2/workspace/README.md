# macOS Wi-Fi Stats App

A small app that displays basic Wi-Fi stats using Next.js and FastAPI.

## Requirements
- macOS system with Wi-Fi enabled
- Python 3.10+
- Node.js 18+

## Backend (FastAPI)
1. Navigate to the backend directory:
   ```bash
   cd backend
   ```
2. Start the Python server:
   ```bash
   uvicorn main:app --reload
   ```

## Frontend (Next.js)
1. Navigate to the frontend directory:
   ```bash
   cd frontend
   ```
2. Install dependencies:
   ```bash
   npm install
   ```
3. Start the Next.js dev server:
   ```bash
   npm run dev
   ```

Visit http://localhost:3000 to see the Wi-Fi stats dashboard.

Note: Ensure both servers are running on separate ports (8000 for backend, 3000 for frontend).