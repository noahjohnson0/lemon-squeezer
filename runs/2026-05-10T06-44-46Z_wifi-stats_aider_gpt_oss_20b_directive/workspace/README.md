# Wi‑Fi Stats App

A minimal full‑stack application that displays the current Wi‑Fi network information on macOS.  
The backend is a FastAPI service that parses the `airport -I` command output.  
The frontend is a Next.js (App Router) app that polls the backend every 3 seconds.

## Prerequisites

- macOS (the `airport` command is macOS‑specific)
- Python 3.10+ (recommended)
- Node.js 18+ (recommended)

## Project Structure

