# PlaneTracker iOS Setup Guide

This guide will help you set up and test the PlaneTracker iOS application on a Mac with Xcode.

## Prerequisites

- **Xcode 14.0 or later** (recommended: Xcode 15.0+)
- **macOS Ventura or later** (for latest Xcode features)
- **iPhone with iOS 15.0+** (required for ARKit support)
- **Active Apple Developer account** (for device testing)
- **Python 3.8+** (for backend server)

## Quick Start

1. **Clone the repository**
2. **Open `PlaneTracker.xcodeproj` in Xcode**
3. **Start the Python backend**
4. **Connect your iPhone and run the app**

## Detailed Setup Instructions

### Step 1: Clone and Open Project

```bash
# Clone the repository
git clone <your-repo-url>
cd PlaneTracker

# Open in Xcode
open PlaneTracker.xcodeproj
```

### Step 2: Configure Code Signing

1. **Select the PlaneTracker project** in the navigator
2. **Select the PlaneTracker target**
3. **Go to "Signing & Capabilities" tab**
4. **Select your development team** from the dropdown
5. **Ensure "Automatically manage signing" is checked**
6. **Note the Bundle Identifier**: `com.planetracker.app`

### Step 3: Backend Setup

The iOS app requires a running Python backend server. Follow these steps:

#### 3.1 Navigate to Backend Directory

```bash
cd Backend
```

#### 3.2 Create Python Virtual Environment

```bash
# Create virtual environment
python3 -m venv venv

# Activate virtual environment
source venv/bin/activate
```

#### 3.3 Install Dependencies

```bash
# Install required packages
pip install -r requirements.txt
```

#### 3.4 Start the Backend Server

```bash
# Start the server
python main.py
```

You should see output like:
```
Server started at http://0.0.0.0:8000
Background refresh task started (8-second intervals)
```

#### 3.5 Verify Backend is Running

Open a new terminal and test:

```bash
# Test health endpoint
curl http://localhost:8000/api/health

# Expected response:
# {"status": "healthy", "timestamp": "2025-10-14T..."}
```

### Step 4: iPhone Connection

#### 4.1 Connect iPhone via USB

1. **Connect your iPhone to the Mac using a USB cable**
2. **Trust the computer** when prompted on iPhone
3. **Enter your iPhone passcode** if requested

#### 4.2 Enable Developer Mode (iOS 16+)

1. **Go to Settings > Privacy & Security > Developer Mode**
2. **Toggle Developer Mode ON**
3. **Restart your iPhone** when prompted
4. **Confirm Developer Mode** after restart

#### 4.3 Trust Development Certificate

1. **Go to Settings > General > VPN & Device Management**
2. **Find your Apple ID under "Developer App"**
3. **Tap "Trust [Your Apple ID]"**
4. **Confirm trust** when prompted

### Step 5: Configure Xcode for iPhone

#### 5.1 Select iPhone as Target

1. **In Xcode, click the device selector** (next to the scheme selector)
2. **Select your connected iPhone** from the list
3. **Ensure it shows "Connected" status**

#### 5.2 Network Configuration

**Important**: Your iPhone and Mac must be on the same WiFi network for the app to connect to the backend.

1. **Connect both devices to the same WiFi network**
2. **Note your Mac's IP address**:
   ```bash
   # Find your Mac's IP address
   ifconfig | grep "inet " | grep -v 127.0.0.1
   ```

3. **Update BackendService.swift if needed** (usually not required for localhost)

### Step 6: Running the App

#### 6.1 Build and Run

1. **Press Cmd+R** or click the "Play" button in Xcode
2. **Wait for the build to complete** (first build may take a few minutes)
3. **The app will install and launch on your iPhone**

#### 6.2 Grant Permissions

On first launch, the app will request permissions:

1. **Camera Access**: Tap "Allow" (required for AR)
2. **Location Access**: Tap "Allow While Using App" (required for flight tracking)
3. **Network Access**: Allow if prompted

#### 6.3 Using the App

1. **Point your iPhone camera at the sky**
2. **Look for aircraft indicators** in the AR view
3. **Tap on aircraft** to see flight information
4. **Use the settings panel** to adjust display options

### Step 7: Running Tests

#### 7.1 Run All Tests

1. **Press Cmd+U** in Xcode
2. **Wait for tests to complete**
3. **Check the Test Navigator** (Cmd+6) for results

#### 7.2 Test Categories

The project includes comprehensive tests:

- **BackendServiceTests**: Network communication and caching
- **FlightModelTests**: Data model validation
- **CoordinatesTests**: Geographic coordinate calculations
- **TrajectoryPredictorTests**: Flight path prediction
- **AltitudeFallbackTests**: Altitude estimation algorithms
- **IntegrationTests**: End-to-end data flow

## Troubleshooting

### Backend Connection Issues

**Problem**: App shows "Backend not available"

**Solutions**:
1. **Verify backend is running**: `curl http://localhost:8000/api/health`
2. **Check firewall settings**: Allow Python through firewall
3. **Ensure same WiFi network**: iPhone and Mac must be on same network
4. **Check Mac's IP address**: Update BackendService.swift if needed

### ARKit Not Working

**Problem**: "AR Not Available" or camera not working

**Solutions**:
1. **Verify device compatibility**: iPhone 6s or later required
2. **Check iOS version**: iOS 15.0+ required
3. **Grant camera permissions**: Settings > Privacy & Security > Camera
4. **Restart the app**: Force quit and relaunch

### Code Signing Errors

**Problem**: "Failed to register bundle identifier" or signing errors

**Solutions**:
1. **Update Bundle Identifier**: Add your initials (e.g., `com.planetracker.app.john`)
2. **Select correct team**: Ensure your Apple ID team is selected
3. **Clean build folder**: Product > Clean Build Folder (Cmd+Shift+K)
4. **Restart Xcode**: Sometimes required after signing changes

### Rate Limit Warnings

**Problem**: "Rate limit reached" in backend logs

**Note**: This is expected behavior from the OpenSky API (free tier: 10 requests/minute). The app will use cached data when rate limits are hit.

### Build Errors

**Problem**: Swift compilation errors

**Solutions**:
1. **Clean build folder**: Product > Clean Build Folder
2. **Update Xcode**: Ensure you're using Xcode 14.0+
3. **Check iOS deployment target**: Should be 15.0
4. **Verify all files are included**: Check project navigator for missing files

## Project Structure

```
PlaneTracker/
├── PlaneTracker.xcodeproj/          # Xcode project file
├── PlaneTrackerApp/                 # Main app source code
│   ├── AppDelegate.swift          # App lifecycle
│   ├── SceneDelegate.swift          # Scene management
│   ├── Views/                       # UI Controllers
│   │   ├── ARView.swift            # Main AR view
│   │   └── PlaneAnnotations.swift  # 3D annotations
│   ├── Models/                      # Data models
│   │   ├── Flight.swift            # Flight data structure
│   │   └── Coordinates.swift       # Coordinate system
│   ├── Services/                    # Business logic
│   │   ├── BackendService.swift    # Backend communication
│   │   ├── OpenSkyService.swift    # Data service layer
│   │   ├── TrajectoryPredictor.swift # Flight prediction
│   │   └── AltitudeFallback.swift  # Altitude estimation
│   ├── Utils/                       # Utilities
│   │   └── MathHelpers.swift       # Mathematical functions
│   ├── Assets.xcassets/             # App icons and assets
│   └── Info.plist                   # App configuration
├── PlaneTrackerTests/               # Unit tests
│   ├── BackendServiceTests.swift   # Backend service tests
│   ├── FlightModelTests.swift       # Model validation tests
│   ├── CoordinatesTests.swift       # Coordinate tests
│   ├── TrajectoryPredictorTests.swift # Prediction tests
│   ├── AltitudeFallbackTests.swift  # Altitude tests
│   ├── IntegrationTests.swift       # End-to-end tests
│   └── Info.plist                   # Test configuration
└── Backend/                         # Python backend
    ├── main.py                      # Backend server
    ├── flights.py                   # Flight data processing
    ├── kalman_filter.py             # Kalman filtering
    └── requirements.txt             # Python dependencies
```

## Architecture Overview

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   iOS App       │    │   Python Backend │    │   OpenSky API   │
│                 │    │                  │    │                 │
│ ┌─────────────┐ │    │ ┌──────────────┐ │    │ ┌─────────────┐ │
│ │ ARView      │ │◄───┤ │ FlightService│ │◄───┤ │ Flight Data  │ │
│ │ (ARKit)     │ │    │ │              │ │    │ │             │ │
│ └─────────────┘ │    │ └──────────────┘ │    │ └─────────────┘ │
│                 │    │                  │    │                 │
│ ┌─────────────┐ │    │ ┌──────────────┐ │    │                 │
│ │BackendService│ │◄───┤ │ CORS Headers │ │    │                 │
│ │             │ │    │ │ Rate Limiting│ │    │                 │
│ └─────────────┘ │    │ │ Caching      │ │    │                 │
│                 │    │ └──────────────┘ │    │                 │
└─────────────────┘    └──────────────────┘    └─────────────────┘
```

## API Endpoints

The backend provides these endpoints:

- `GET /api/health` - Health check
- `GET /api/flights` - Get all flights
- `GET /api/flights/{id}` - Get specific flight
- `GET /api/flights/{id}/trajectory` - Get flight trajectory
- `GET /api/flights/{id}/altitude` - Get altitude prediction

## Development Tips

### Debugging

1. **Use Xcode's debugger**: Set breakpoints in Swift code
2. **Check console output**: View logs in Xcode's console
3. **Test backend separately**: Use curl or Postman to test API
4. **Monitor network traffic**: Use Xcode's Network Inspector

### Performance

1. **ARKit optimization**: Limit number of AR objects
2. **Backend caching**: 8-second cache reduces API calls
3. **Memory management**: ARKit objects are automatically managed
4. **Battery usage**: ARKit is power-intensive, use sparingly

### Testing Strategy

1. **Unit tests**: Test individual components
2. **Integration tests**: Test data flow
3. **Device testing**: Test on physical iPhone
4. **Network testing**: Test with/without backend connection

## Next Steps

After successful setup:

1. **Customize app icons**: Replace placeholder icons in Assets.xcassets
2. **Add more flight data sources**: Extend BackendService for additional APIs
3. **Improve AR visualization**: Enhance 3D models and animations
4. **Add user preferences**: Implement settings for display options
5. **Deploy backend**: Move from localhost to cloud hosting

## Support

If you encounter issues:

1. **Check this guide first**: Most common issues are covered
2. **Review Xcode console**: Look for error messages
3. **Test backend independently**: Verify Python server is working
4. **Check device compatibility**: Ensure iPhone supports ARKit
5. **Update dependencies**: Ensure latest Xcode and iOS versions

## Success Criteria

You'll know the setup is successful when:

✅ Xcode project opens without errors  
✅ All Swift files compile successfully  
✅ Unit tests pass (Cmd+U)  
✅ App launches on iPhone  
✅ Camera and location permissions granted  
✅ Backend connection established  
✅ AR view displays (even if no aircraft visible)  
✅ No error messages in console  

The app is ready for development and testing!
