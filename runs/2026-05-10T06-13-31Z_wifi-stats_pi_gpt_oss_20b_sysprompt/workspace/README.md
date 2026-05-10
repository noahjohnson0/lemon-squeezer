# WiFi Stats App

This repository contains a small **Next.js + FastAPI** application that displays basic Wi‑Fi statistics of the user’s current network on macOS.

## Overview

* **Backend** – A FastAPI service exposing a single endpoint `GET /api/wifi` that returns JSON with network details (ssid, bssid, rssi, channel, tx_rate, security).
* **Frontend** – A Next.js app (App Router) that polls the /api endpoint every 3 seconds and displays the data in a clean card layout.

## Prerequisites

1. Python 3.10+ (for the backend).
2. Node.js 18+ and npm (for the frontend).
3. macOS – the backend uses the built‑in `airport` utility.

## Running the Application

```bash
# In a terminal, navigate to the repository root.
```

### 1. Start the Backend

```bash
cd backend
# Create a virtual environment if you wish
python -m venv .venv
source .venv/bin/activate  # On Windows: .venv\Scripts\activate
pip install -r requirements.txt
uvicorn main:app --reload
```
The API will be available at `http://localhost:8000/api/wifi`.

### 2. Start the Frontend

Open a new terminal window/tab and execute:

```bash
cd frontend
npm install
npm run dev
```
The Next.js dev server will start on `http://localhost:3000` and will automatically fetch data from the FastAPI backend.

> **Note**: If the backend is running on a different host or port, adjust the fetch URL in `app/page.tsx` accordingly.

## Project Structure
```
├─ backend/
│   ├─ main.py
│   └─ requirements.txt
├─ frontend/
│   ├─ app/
│   │   ├─ layout.tsx
│   │   ├─ page.tsx
│   │   └─ components/
│   │       └─ StatsCard.tsx
│   ├─ package.json
│   ├─ tsconfig.json
│   └─ next.config.js
└─ README.md
```

## License
This project is open source and free to use.
