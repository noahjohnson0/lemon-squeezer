# Wi‑Fi Stats App

This repository contains a small full‑stack application that displays basic Wi‑Fi statistics for the current network on macOS.

The stack consists of:

* **Backend** – FastAPI (Python) exposing a single endpoint `/api/wifi`.
* **Frontend** – Next.js (App Router) that polls the backend every 3 seconds and shows the data in a card.

## Prerequisites

* macOS (tested on macOS 13+)
* Python 3.10+
* Node.js 18+ (or 20+)

## Setup

### Backend

