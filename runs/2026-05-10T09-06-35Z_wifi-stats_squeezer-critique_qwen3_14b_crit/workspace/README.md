# Wi-Fi Stats App

## Features
- Displays current Wi-Fi network information on macOS
- Auto-refreshes every 3 seconds

## Requirements
- macOS
- Python 3.8+
- Node.js 18+

## Setup Instructions

### 1. Install dependencies
```bash
# Python dependencies
pip install -r backend/requirements.txt

# Node dependencies
npm install --prefix frontend
```

### 2. Run the app
```bash
# Start Python backend
uvicorn backend.main:app --reload --port 8000 &

# Start Next.js frontend
npm run dev --prefix frontend
```

## API Endpoints
- `GET /api/wifi` - Returns Wi-Fi network information in JSON format

## License
MIT