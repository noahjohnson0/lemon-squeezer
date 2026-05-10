# Wi‑Fi Stats App

A small full‑stack application that displays basic Wi‑Fi statistics of the current network on macOS.

## Architecture

- **Backend** – FastAPI (Python) exposing `/api/wifi`.
- **Frontend** – Next.js (App Router) fetching the endpoint every 3 s and rendering the data.

## Prerequisites

- macOS (the backend uses the `airport` command which is only available on macOS).
- Python 3.9+.
- Node.js 18+.

## Setup

### Backend

