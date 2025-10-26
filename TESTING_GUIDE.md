# PlaneTracker Testing Guide

## Quick Test Results ✅

**Backend Status:** All systems operational
- ✅ Health check: PASS
- ✅ Flight data: 9 active flights detected
- ✅ API endpoints: All responding
- ✅ Network: `10.103.2.166:8000` (via Tailscale)

## Testing the Backend (Already Done ✅)

The backend is confirmed working. You can re-test anytime:

```bash
./test_backend_complete.sh
```

Or manually:
```bash
# Health check
curl http://10.103.2.166:8000/api/health

# Get flights
curl http://10.103.2.166:8000/api/flights | python3 -m json.tool | head -50
```

## Testing the iOS App

### Step 1: Open Xcode Project

```bash
open PlaneTracker.xcodeproj
```

### Step 2: Build Settings Check

1. **Select your iPhone** as the deployment target (not simulator - ARKit needs real device)
2. **Signing & Capabilities**:
   - Click on `PlaneTracker` project in left sidebar
   - Select `PlaneTracker` target
   - Go to "Signing & Capabilities" tab
   - Ensure "Automatically manage signing" is checked
   - Select your Team from the dropdown

### Step 3: Verify Backend IP Address

The backend URL is now correctly set in `BackendService.swift`:

```swift
// Line 7
return "http://10.103.2.166:8000"
```

**Note:** If your Tailscale IP changes, update this line.

### Step 4: Build and Run

1. **Connect your iPhone** via USB or WiFi debugging
2. **Trust your computer** on the iPhone if prompted
3. **Press Cmd+R** to build and run
4. **Watch the Xcode console** for any errors

### Step 5: Check iOS Console Output

You should see in the Xcode console:

```
✅ Good signs:
- "Background refresh completed at..."
- "WebSocket connection established..."
- HTTP 200 responses from backend
- Flight data being received

⚠️ Warning signs (but might be OK):
- Rate limit warnings from OpenSky (expected)

❌ Bad signs:
- "Failed to connect to backend"
- "No data received"
- HTTP error codes (404, 500, etc.)
```

### Step 6: Test on Device

When the app launches:

1. **Grant camera/AR permissions** when prompted
2. **Point your iPhone at the sky**
3. **Look for:**
   - Red aircraft markers in AR space
   - Flight callsigns (labels above aircraft)
   - Blue trajectory lines showing flight paths

### Step 7: Debugging No Flight Data

If you see the AR view but **no flights appear**, check:

#### A. Console Logs in Xcode
Press **Cmd+Shift+2** to open the debug console and look for:
- Network errors
- JSON parsing errors
- Backend connection failures

#### B. Test Backend Connection from iOS
The app tries to connect every 5 seconds. Watch for these log patterns:

```swift
// You should see logs like:
"Background refresh completed..."  // Backend is working
"Fetching flights from backend..." // App is trying
"Received X flights"               // Success!

// Bad patterns:
"Error fetching flights..."        // Network issue
"Invalid response from backend"    // Backend issue
```

#### C. Check WiFi/Network
Both devices must be on same network or connected via Tailscale:
- iPhone: Settings → WiFi
- Laptop: Check Tailscale is running

#### D. Verify Backend is Still Running
In terminal:
```bash
curl http://10.103.2.166:8000/api/health
```

Should return: `{"status": "healthy", "timestamp": "..."}`

## Common Issues and Solutions

### Issue 1: "Backend not responding"
**Solution:** 
1. Check if Python backend is running
2. In terminal: `cd Backend && python main.py`
3. Verify you see: "Server started at http://0.0.0.0:8000"

### Issue 2: "No flights visible in AR"
**Possible causes:**
1. **No flights in area**: Try at different times (more flights during day)
2. **AR coordinate issue**: The coordinate conversion might need tuning
3. **Flights out of view**: Try different directions/elevations
4. **Backend working but UI not updating**: Check console for errors

**Debug steps:**
```bash
# Check if flights are available
curl http://10.103.2.166:8000/api/flights | python3 -c "
import sys, json
data = json.load(sys.stdin)
print(f'Flight count: {data[\"count\"]}')
for f in data['flights'][:5]:
    print(f'{f[\"callsign\"]}: {f[\"latitude\"]:.4f}, {f[\"longitude\"]:.4f}')
"
```

### Issue 3: "Build failed in Xcode"
**Common solutions:**
1. Clean build folder: **Cmd+Shift+K**
2. Close and reopen Xcode
3. Check for missing imports
4. Verify code signing settings

### Issue 4: "IP address changed"
If your Tailscale IP changes:
1. Find new IP: `tailscale ip -4`
2. Update `BackendService.swift` line 7
3. Rebuild app

## Test Checklist

- [ ] Backend running on laptop (`./test_backend_complete.sh`)
- [ ] Backend health check passes
- [ ] Backend returns flight data
- [ ] iPhone connected to same network or Tailscale
- [ ] Xcode project opens without errors
- [ ] Code signing configured
- [ ] App builds successfully (Cmd+R)
- [ ] AR permissions granted on device
- [ ] No console errors in Xcode
- [ ] Flight data appears in AR view

## Expected Behavior

When everything works:
1. **App launches** → AR view starts
2. **Every 5 seconds** → App fetches flights from backend
3. **Backend caches for 8 seconds** → Reduces API calls
4. **Flights appear as**:
   - Red box shapes (aircraft)
   - White text labels (callsigns)
   - Blue lines (trajectories)

## Getting More Debug Info

### Enable Verbose Logging

Add to `ARView.swift` in the `setupBackendSubscriptions()` function:

```swift
backendService.$flights
    .sink { [weak self] flights in
        print("📍 Received \(flights.count) flights")
        for flight in flights {
            print("  ✈️ \(flight.callsign): \(flight.latitude ?? 0), \(flight.longitude ?? 0)")
        }
        self?.currentFlights = flights
        self?.updateFlightTrajectories()
        self?.updateARVisualization()
    }
    .store(in: &cancellables)
```

### Monitor Network Requests

Add to `BackendService.swift` in the `fetchFlights()` function:

```swift
print("🌐 Fetching flights from: \(url.absoluteString)")
```

## Next Steps if Still Not Working

1. **Check this guide step-by-step** ✓
2. **Run backend tests** ✓
3. **Check Xcode console** for specific errors
4. **Share console output** for debugging
5. **Verify ARKit permissions** in Settings → PlaneTracker

## Quick Reference

**Backend URL:** `http://10.103.2.166:8000`  
**Test backend:** `./test_backend_complete.sh`  
**Check health:** `curl http://10.103.2.166:8000/api/health`  
**View flights:** `curl http://10.103.2.166:8000/api/flights`  

**Files changed:** `BackendService.swift` (fixed health check URL from `/health` to `/api/health`)

