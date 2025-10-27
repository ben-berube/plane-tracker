# PlaneTracker

An iOS AR app that displays real-time aircraft in augmented reality using your iPhone's camera.

## Overview

PlaneTracker overlays live flight data onto your camera view, showing planes as 3D objects in AR space with their flight paths, callsigns, and detailed information. Built with ARKit and CoreLocation, it fetches real-time data directly from the OpenSky Network API.

### Key Features

- **Real-time AR Visualization**: See planes floating in 3D space with their actual flight paths
- **Live Flight Data**: Direct integration with OpenSky Network API (refreshes every 8 seconds)
- **Interactive Compass**: Radar-style compass shows plane bearings relative to your location
- **Flight Details**: Tap any plane to see altitude, speed, distance, and flight info
- **Browse Mode**: Swipe through all available flights with shuffle navigation
- **Digital Zoom**: Pinch-to-zoom with visual slider (up to 5x magnification)
- **Device Location**: Uses your actual GPS coordinates to position planes accurately

## Tech Stack

- **Swift** with **ARKit** for AR visualization
- **SceneKit** for 3D rendering
- **CoreLocation** for GPS tracking
- **Combine** for reactive data flow
- **OpenSky Network API** for flight data

## Setup & Installation

### Prerequisites

- **macOS** with **Xcode 14.0+**
- **iPhone** with **iOS 15.0+** (ARKit requires iOS 11+, tested on iOS 15+)
- **Apple Developer Account** (for running on physical device)
- **Active WiFi** or cellular connection

### Quick Start

1. **Clone the repository**
   ```bash
   git clone <repo-url>
   cd plane-tracker
   ```

2. **Open in Xcode**
   ```bash
   open PlaneTracker.xcodeproj
   ```

3. **Configure signing**
   - Select the project in Xcode
   - Go to "Signing & Capabilities"
   - Select your development team
   - Xcode will automatically manage your provisioning profile

4. **Connect your iPhone**
   - Connect via USB cable
   - Trust the computer on your iPhone if prompted
   - Select your device as the run destination in Xcode

5. **Build and run**
   - Press `Cmd + R` or click the Play button
   - Grant location permissions when prompted
   - Point your camera at the sky!

### Location Permissions

The app requires location access to:
- Calculate distances to aircraft
- Show compass bearings relative to your position
- Position planes accurately in AR space

You'll be prompted to grant "Location While Using App" on first launch.

## How It Works

1. **Data Fetching**: App queries OpenSky Network API for flights in the SF Bay Area
2. **Coordinate Conversion**: Converts latitude/longitude/altitude to AR world coordinates
3. **AR Rendering**: Creates 3D planes, trajectory lines, and compass overlay
4. **Interaction**: Tap planes for details, swipe to browse, use pinch-to-zoom

### Coordinate System

- Uses a **1:1000 scale** (1km in real world = 1 meter in AR)
- Planes positioned relative to your device's GPS location
- Billboard constraints keep labels facing the camera

## Project Structure

```
PlaneTracker/
├── PlaneTrackerApp/           # iOS application
│   ├── Models/               # Flight.swift, Coordinates.swift
│   ├── Services/             # OpenSkyService.swift, TrajectoryPredictor.swift
│   ├── Views/                # ARView.swift, LoadingViewController.swift
│   └── Utils/                # MathHelpers.swift
├── PlaneTrackerAppTests/     # Unit tests
└── PlaneTracker.xcodeproj    # Xcode project
```

## Usage

### Viewing Planes
- Point your camera at the sky
- Red indicators mark planes in AR space
- Tapped planes turn cyan
- Text labels always face you for easy reading

### Compass Overlay
- Fixed red arrow points north
- NSEW labels rotate with your device
- Red dots show plane bearings
- Tap "Shuffle Flight" to browse with a specialized compass

### Flight Details
- Tap any plane to open its detail card
- Shows flight number, airline, origin, distance, speed, altitude
- Swipe left/right to browse other flights
- Flight codes are selectable for lookup

### Zoom Controls
- Pinch in/out or use the slider
- Distant planes maintain minimum size for visibility
- Up to 5x magnification

## Troubleshooting

### No Planes Showing
- Check internet connection (app fetches live data)
- Ensure location permissions are granted
- Try pointing camera at different angles
- Wait 8 seconds for data refresh

### AR Not Working
- Requires iPhone 6s or later
- Needs iOS 15.0+
- Ensure camera isn't covered
- Try relaunching the app

### Location Issues
- Grant "Location While Using App" permission
- Ensure GPS is enabled in Settings
- May not work indoors (GPS requires line-of-sight to satellites)

## Development

### Building Tests
```bash
# Run unit tests in Xcode
Cmd + U
```

### Data Refresh Rate
- OpenSky API cached for 8 seconds
- Rate limited to avoid API throttling
- Real-time updates for moving aircraft

### API Integration
Direct HTTPS calls to:
```
https://opensky-network.org/api/states/all
```

## License

MIT License

## Credits

- **OpenSky Network** for flight data: https://opensky-network.org
- Built with **ARKit** and **SceneKit**
- Real-time aircraft tracking powered by crowd-sourced ADS-B data
