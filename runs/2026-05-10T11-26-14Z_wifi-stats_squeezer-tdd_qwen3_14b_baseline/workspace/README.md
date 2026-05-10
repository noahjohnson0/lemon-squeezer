# Wi-Fi Stats App

This app displays Wi-Fi network statistics on macOS using FastAPI (Python) backend and Next.js frontend.

## Requirements
- macOS (airport command available)
- Python 3.8+
- Node.js 18+

## How to Run

### Backend (Python)
1. Navigate to the backend directory:
   ```bash
   cd backend
   ```
2. Run the FastAPI server:
   ```bash
   uvicorn main:app --reload
   ```

### Frontend (Next.js)
1. Navigate to the frontend directory:
   ```bash
   cd frontend
   ```
2. Start the development server:
   ```bash
   npm run dev
   ```

Open http://localhost:3000 in your browser to view the Wi-Fi stats.