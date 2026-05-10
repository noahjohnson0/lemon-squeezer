# A simple README to guide users in running both services.

# WiFi Stats App

This repository contains a tiny full‑stack demo that reports Wi‑Fi details of the host machine **on macOS**.

The stack
--------

* **Python FastAPI** – a small backend that runs a system command (`airport -I`) to read the current wireless state and returns it as JSON.
* **Next.js 13 App Router** – a tiny frontend that polls the `/api/wifi` endpoint every 3 s and displays the data in a card.
*
No NPM packages or pip requirements are installed automatically – the instructions below show how to get both parts running.

## Prerequisites

* macOS 10.15+ (the `airport` binary that ships with macOS is required).
* Python 3.9+ installed.
* Node.js 18+.

## Running the backend

```bash
cd backend
python -m venv .venv   # optional but recommended
source .venv/bin/activate
pip install fastapi uvicorn
python main.py   # the script starts uvicorn on 0.0.0.0:8000
```

The endpoint is at `http://localhost:8000/api/wifi`.

## Running the frontend

```bash
cd frontend
npm install              # installs next, react, etc.
# Start a tiny reverse proxy that forwards /api/* to the backend
node proxy.js &
# Start the Next.js dev server (listens on :3000)
npm run dev
```

Open http://localhost:3000 in a browser – you should see a card that updates every 3 s with your current Wi‑Fi name, BSSID, signal strength, channel, and TX‑rate.

### Note about CORS

The proxy simply forwards requests; if you launch the FastAPI server directly without the proxy you may need to allow `http://localhost:3000` via CORS – the app router is configured to accept any origin.

---

Happy hacking!
