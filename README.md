# PlaneTracker

An AR-powered iOS application for tracking and visualizing aircraft in the San Francisco Bay Area using real-time flight data from the OpenSky Network.

## Features

- **Real-time Flight Tracking**: Fetches live flight data from OpenSky Network API
- **AR Visualization**: Displays aircraft as 3D annotations in augmented reality
- **SF Bay Area Focus**: Filters flights specifically for the San Francisco Bay Area
- **Altitude Fallback**: Intelligent estimation of missing altitude data
- **3D Positioning**: Converts geographic coordinates to ARKit world coordinates

## Project Structure

```
PlaneTracker/
│
├─ PlaneTrackerApp/        # iOS Swift app
│   ├─ AppDelegate.swift
│   ├─ SceneDelegate.swift
│   ├─ Views/
│   │   ├─ ARView.swift           # Main AR view
│   │   └─ PlaneAnnotations.swift # 3D plane markers
│   ├─ Models/
│   │   ├─ Flight.swift           # Flight data model
│   │   └─ Coordinates.swift     # Lat/Lon/Alt helper
│   ├─ Services/
│   │   ├─ OpenSkyService.swift   # Fetch + filter SF Bay flights
│   │   └─ AltitudeFallback.swift # Logic for estimating missing altitudes
│   └─ Utils/
│       └─ MathHelpers.swift      # Helper functions for AR positioning
│
├─ Backend/                 # Optional (Python/Node)
│   ├─ main.py
│   ├─ flights.py            # Fetch/filter flights
│   └─ requirements.txt
│
└─ README.md
```

## iOS App Components

### Views
- **ARView.swift**: Main ARKit view controller for displaying aircraft in AR
- **PlaneAnnotations.swift**: 3D scene nodes representing aircraft with labels

### Models
- **Flight.swift**: Data model for flight information from OpenSky API
- **Coordinates.swift**: Helper for coordinate conversion and calculations

### Services
- **OpenSkyService.swift**: Handles API communication and data fetching
- **AltitudeFallback.swift**: Estimates missing altitude data using velocity and flight phase

### Utils
- **MathHelpers.swift**: Mathematical utilities for coordinate conversion and AR positioning

## Backend (Optional)

The Python backend provides additional flight data processing and filtering capabilities:

- **main.py**: FastAPI server with endpoints for flight data
- **flights.py**: Flight data service with filtering and statistics
- **requirements.txt**: Python dependencies

### Backend Setup

```bash
cd Backend
pip install -r requirements.txt
python main.py
```

## API Endpoints

- `GET /api/flights` - Get all flights in SF Bay area
- `GET /api/flights/{flight_id}` - Get specific flight by ICAO24 ID
- `GET /health` - Health check endpoint

## Requirements

### iOS App
- iOS 13.0+
- Xcode 12.0+
- ARKit framework
- CoreLocation framework

### Backend
- Python 3.8+
- aiohttp
- asyncio

## Data Sources

- **OpenSky Network**: Real-time flight data API
- **Geographic Bounds**: San Francisco Bay Area (37.4°N to 38.0°N, -122.6°W to -121.8°W)

## Key Features

1. **Real-time Data**: Fetches live flight data every few seconds
2. **AR Visualization**: Places 3D aircraft markers in AR space
3. **Intelligent Filtering**: Focuses on relevant flights in the SF Bay area
4. **Altitude Estimation**: Handles missing altitude data intelligently
5. **Coordinate Conversion**: Converts GPS coordinates to ARKit world coordinates

## Development Notes

- The app uses ARKit for AR visualization
- OpenSky Network API provides free real-time flight data
- Coordinate conversion handles the transformation from GPS to ARKit coordinates
- Altitude fallback uses velocity and flight phase to estimate missing data
- The backend is optional but provides additional data processing capabilities

## License

This project is for educational and personal use. Please respect the OpenSky Network API terms of service.
