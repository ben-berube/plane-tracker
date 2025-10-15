# PlaneTracker

A real-time aircraft tracking system with augmented reality visualization, built with Python backend and iOS frontend.

## Overview

PlaneTracker combines real-time flight data with augmented reality to provide an immersive aircraft tracking experience. The system features advanced trajectory prediction, intelligent altitude estimation, and optimized caching for reliable performance.

## Quick Start

### For iOS Development

1. **Clone the repository**
2. **Open `PlaneTracker.xcodeproj` in Xcode**
3. **Follow the [XCODE_SETUP_GUIDE.md](XCODE_SETUP_GUIDE.md) for detailed setup instructions**

### For Backend Development

1. **Navigate to `Backend/` directory**
2. **Follow the [Backend/README.md](Backend/README.md) for Python server setup**

## Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   iOS App       │    │   Python Backend │    │   OpenSky API   │
│   (ARKit)       │◄───┤   (Data Processing)│◄───┤   (Flight Data) │
└─────────────────┘    └──────────────────┘    └─────────────────┘
```

### Key Components

- **iOS App**: ARKit-based augmented reality visualization
- **Python Backend**: Flight data processing and API serving
- **OpenSky API**: Real-time aircraft data source
- **Kalman Filtering**: Advanced trajectory prediction
- **Intelligent Caching**: Optimized data retrieval

## Features

- **Real-time Flight Tracking**: Live aircraft data with 8-second refresh
- **Augmented Reality**: ARKit-based 3D aircraft visualization
- **Trajectory Prediction**: Kalman filtering for flight path forecasting
- **Altitude Estimation**: Multi-source altitude data with confidence scoring
- **Performance Optimization**: Intelligent caching and rate limit handling
- **Cross-platform**: iOS app with Python backend

## Project Structure

```
PlaneTracker/
├── PlaneTracker.xcodeproj/     # Xcode project file
├── PlaneTrackerApp/            # iOS application source
│   ├── Models/                # Data models (Flight, Coordinates)
│   ├── Services/              # Business logic (Backend, OpenSky)
│   ├── Views/                 # UI controllers (ARView, Annotations)
│   ├── Utils/                 # Utility functions (MathHelpers)
│   └── Assets.xcassets/       # App icons and assets
├── PlaneTrackerTests/          # iOS unit tests
├── Backend/                   # Python backend server
│   ├── main.py               # Main server application
│   ├── flights.py            # Flight data processing
│   ├── kalman_filter.py      # Kalman filtering algorithms
│   └── requirements.txt      # Python dependencies
├── XCODE_SETUP_GUIDE.md       # Comprehensive iOS setup guide
└── README.md                  # This file
```

## Getting Started

### Prerequisites

- **Xcode 14.0+** (for iOS development)
- **Python 3.8+** (for backend server)
- **iPhone with iOS 15.0+** (for ARKit support)
- **Apple Developer Account** (for device testing)

### Setup Instructions

1. **iOS Development**: See [XCODE_SETUP_GUIDE.md](XCODE_SETUP_GUIDE.md) for complete setup
2. **Backend Development**: See [Backend/README.md](Backend/README.md) for Python server setup

## API Endpoints

The backend provides these REST endpoints:

- `GET /api/health` - Health check
- `GET /api/flights` - Get all flights
- `GET /api/flights/{id}` - Get specific flight
- `GET /api/flights/{id}/trajectory` - Get flight trajectory
- `GET /api/flights/{id}/altitude` - Get altitude prediction

## Testing

### iOS Tests
- **Unit Tests**: Press Cmd+U in Xcode
- **Test Coverage**: Backend service, models, coordinates, trajectory, altitude
- **Integration Tests**: End-to-end data flow validation

### Backend Tests
```bash
cd Backend
python test_enhanced_api.py
python test_optimized_api.py
```

## Performance

- **8-second cache duration** for optimal API usage
- **Rate limit handling** for OpenSky API (10 requests/minute)
- **Background processing** for continuous data updates
- **Memory optimization** for ARKit rendering
- **CORS support** for iOS app connectivity

## Requirements

### iOS App
- **Xcode 14.0+**
- **iOS 15.0+**
- **iPhone 6s or later** (for ARKit)
- **Active Apple Developer Account**

### Backend
- **Python 3.8+**
- **aiohttp** (async HTTP server)
- **numpy** (numerical computing)
- **python-dateutil** (date utilities)

## Development

### iOS Development
1. **Open `PlaneTracker.xcodeproj` in Xcode**
2. **Select your development team** in project settings
3. **Connect iPhone** and select as deployment target
4. **Build and run** (Cmd+R)

### Backend Development
1. **Navigate to `Backend/` directory**
2. **Create virtual environment**: `python3 -m venv venv`
3. **Activate environment**: `source venv/bin/activate`
4. **Install dependencies**: `pip install -r requirements.txt`
5. **Start server**: `python main.py`

## Troubleshooting

### Common Issues
- **Backend connection**: Ensure iPhone and Mac on same WiFi network
- **ARKit not working**: Verify device compatibility and permissions
- **Code signing errors**: Update bundle identifier and select correct team
- **Rate limit warnings**: Expected behavior from OpenSky API

### Getting Help
1. **Check setup guides** for detailed troubleshooting
2. **Review Xcode console** for error messages
3. **Test backend independently** with curl commands
4. **Verify device compatibility** for ARKit support

## Contributing

1. **Fork the repository**
2. **Create feature branch**: `git checkout -b feature/new-feature`
3. **Make changes and test thoroughly**
4. **Run tests**: iOS (Cmd+U) and Backend (`python -m pytest`)
5. **Submit pull request** with description

## License

MIT License - see LICENSE file for details

## Support

For issues and questions:
1. **Check the setup guides** first
2. **Review error logs** for specific issues
3. **Test components independently** to isolate problems
4. **Verify network connectivity** between devices

The project is designed to be robust and self-healing, with comprehensive error handling and graceful degradation when external services are unavailable.