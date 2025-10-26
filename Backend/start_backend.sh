#!/bin/bash
# Kill any existing Python processes on port 8000
lsof -ti:8000 | xargs kill -9 2>/dev/null

# Activate virtual environment
cd "$(dirname "$0")"
source venv/bin/activate

# Start backend
echo "Starting PlaneTracker backend on port 8000..."
python main.py

