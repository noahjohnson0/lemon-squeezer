# Wi-Fi Stats App

This is a small Next.js + Python (FastAPI) app that displays basic Wi-Fi stats about the user's current network on macOS.

## Backend (FastAPI)

1. Navigate to the `backend` directory:
   ```sh
   cd backend
   ```

2. Install the required dependencies:
   ```sh
   pip install -r requirements.txt
   ```

3. Run the FastAPI server:
   ```sh
   uvicorn main:app --reload
   ```

The backend will be available at `http://localhost:8000`.

## Frontend (Next.js)

1. Navigate to the `frontend` directory:
   ```sh
   cd frontend
   ```

2. Install the required dependencies:
   ```sh
   npm install
   ```

3. Run the Next.js development server:
   ```sh
   npm run dev
   ```

The frontend will be available at `http://localhost:3000`.

## Usage

1. Start the backend server as described above.
2. Start the frontend server as described above.
3. Open your browser and navigate to `http://localhost:3000` to see the Wi-Fi stats displayed in a clean card layout.

The frontend fetches data from the backend every 3 seconds and updates the display accordingly.
