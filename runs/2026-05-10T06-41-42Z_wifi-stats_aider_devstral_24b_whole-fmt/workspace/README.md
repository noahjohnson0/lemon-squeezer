# Wi-Fi Stats App

This app displays basic Wi-Fi stats about the user's current network on macOS.

## Backend (FastAPI)

1. Navigate to the `backend` directory:
   ```sh
   cd backend
   ```

2. Install dependencies:
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

2. Install dependencies:
   ```sh
   npm install
   ```

3. Run the Next.js development server:
   ```sh
   npm run dev
   ```

The frontend will be available at `http://localhost:3000`.

## Usage

1. Start both servers as described above.
2. Open your browser and navigate to `http://localhost:3000`.
3. The page will display the Wi-Fi stats and update every 3 seconds.

