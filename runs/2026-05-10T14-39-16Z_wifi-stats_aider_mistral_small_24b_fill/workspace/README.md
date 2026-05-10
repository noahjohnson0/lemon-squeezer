# Wi-Fi Stats App

This application displays basic Wi-Fi stats about the user's current network on macOS.

## Backend (FastAPI)

1. Navigate to the `backend` directory.
2. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```
3. Run the server:
   ```bash
   uvicorn main:app --reload
   ```

## Frontend (Next.js)

1. Navigate to the `frontend` directory.
2. Install dependencies:
   ```bash
   npm install
   ```
3. Run the development server:
   ```bash
   npm run dev
   ```

The frontend will fetch Wi-Fi stats from the backend every 3 seconds and display them in a clean card layout.
