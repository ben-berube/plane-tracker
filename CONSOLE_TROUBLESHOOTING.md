# Console Troubleshooting Guide

## Current Status ✅

**GOOD NEWS:**
- ✅ App builds successfully
- ✅ App runs on device
- ✅ Camera/AR permissions granted
- ✅ Backend running with 9 flights available
- ✅ Code has extensive NSLog() debugging

**THE MYSTERY:**
- ❌ Xcode console shows NO output at all
- This is an Xcode/device console configuration issue, NOT a code problem

---

## Alternative Ways to See Logs (When Ready to Debug)

### Method 1: Device Console (Most Reliable)

1. **Window → Devices and Simulators** in Xcode
2. Select your iPhone
3. Click **"Open Console"** button at bottom-right
4. In the filter box, type: **PlaneTracker**
5. You should see ALL NSLog output here

This bypasses Xcode's buggy console!

### Method 2: Console.app (macOS Built-in)

1. Open **Console.app** (from Applications/Utilities)
2. Select your iPhone from left sidebar
3. In search box, type: **PlaneTracker**
4. Start the app - logs will appear here

### Method 3: Terminal with `log stream`

```bash
# While iPhone is connected via USB
log stream --predicate 'process == "PlaneTracker"' --level debug
```

---

## What the Logs Should Show

When working correctly, you'll see:

```
🚀🚀🚀 ARView viewDidLoad called!
✅ ARSCNView created and added to view
✅ Scene created and configured
🔔 Setting up backend subscriptions...
🚀🚀🚀 ARView: Starting flight data updates...
📡 Backend URL: http://10.103.2.166:8000
🌐 Calling fetchFlights() for the first time...
✅ Timer scheduled successfully
🔵 BackendService.fetchFlights() called
🌐 BackendService: Fetching from http://10.103.2.166:8000/api/flights
✅✅✅ BackendService: Successfully fetched 9 flights
🛫 ARView: Received 9 flights from backend
  ✈️ QXE2086: lat=37.7311, lon=-122.2603, alt=381
  ✈️ N51HF: lat=37.4366, lon=-122.1950, alt=869
  ✈️ DAL365: lat=37.6508, lon=-122.4093, alt=3307
```

---

## Potential Xcode Console Issues

### Issue 1: Console Filter Active
- Check the bottom of the console for a search box
- Make sure it's empty (no filter text)
- Check the dropdown says "All Output"

### Issue 2: Xcode Scheme Settings
1. **Product → Scheme → Edit Scheme**
2. Select **Run** on left
3. Go to **Options** tab
4. Make sure "Console" is set to **Target Output**

### Issue 3: Derived Data Corruption
```bash
# Close Xcode, then run:
rm -rf ~/Library/Developer/Xcode/DerivedData/*
# Reopen and rebuild
```

### Issue 4: Device Logs Not Streaming
Sometimes Xcode loses connection to device logs:
1. Unplug iPhone
2. Quit Xcode completely
3. Plug iPhone back in
4. Trust computer again if prompted
5. Reopen Xcode and run

---

## Visual Debugging (No Console Needed!)

Since the app IS running, you can debug visually:

### Check If Data Is Being Fetched

Add a **visible indicator** on screen:

1. The **FPS counter** at top-left shows AR is working
2. Try adding a test node to see if AR is rendering

### Backend Test (Independent)

```bash
# Run this every 5 seconds and watch for changes
watch -n 5 'curl -s http://10.103.2.166:8000/api/flights | python3 -c "import sys, json; data = json.load(sys.stdin); print(f\"Time: $(date +%H:%M:%S) - Flights: {data[\"count\"]}\")"'
```

---

## Why Flights Might Not Be Visible (Even If Data Is Fetched)

### 1. AR Coordinate Conversion
The current conversion is **VERY SIMPLIFIED**:
```swift
let x = Float(altitude * cos(latRad) * cos(lonRad)) / 1000
let y = Float(altitude * sin(latRad)) / 1000
let z = Float(altitude * cos(latRad) * sin(lonRad)) / 1000
```

This places objects at:
- **Altitude in meters** / 1000 (so 381m → 0.381 units)
- Objects might be **extremely small** or **too close/far** to see

### 2. Scale Issues
- Aircraft boxes are 0.5 x 0.2 x 1.0 units
- At the current coordinate scale, they might be microscopic
- Text labels are scaled to 0.1 - likely invisible

### 3. No Reference Location
The code doesn't use your actual GPS location as reference, so:
- All planes are positioned relative to (0,0,0) in AR space
- They might all be thousands of units away in one direction

---

## Next Steps for Later

When you're ready to debug further:

1. **Try Method 1, 2, or 3 above to see logs**
2. **If data IS being fetched** (logs show flights), the issue is rendering
3. **If data is NOT being fetched**, check network/permissions

### Quick Fix to Test Rendering

Add a test cube at origin to confirm AR is working:

```swift
// In viewDidLoad(), after setting up scene:
let testBox = SCNBox(width: 1, height: 1, length: 1, chamferRadius: 0)
testBox.firstMaterial?.diffuse.contents = UIColor.red
let testNode = SCNNode(geometry: testBox)
testNode.position = SCNVector3(0, 0, -5)  // 5 meters in front
sceneView.scene.rootNode.addChildNode(testNode)
NSLog("✅ Test red cube added at (0,0,-5)")
```

If you see the red cube, AR rendering works - issue is coordinate conversion.

---

## Summary

**What Works:**
- Build system ✅
- AR framework ✅  
- Permissions ✅
- Backend ✅
- Network connectivity ✅

**What's Unknown:**
- Is data actually being fetched? (can't see logs)
- Is rendering working? (can't see logs)

**Most Likely Issue:**
Either Xcode console bug OR coordinate conversion makes planes invisible.

---

## Contact Info / Resources

- Backend running on: `http://10.103.2.166:8000`
- Test script: `./test_backend_complete.sh`
- Backend has: 9 flights in SF Bay Area
- All code has NSLog() debugging (just can't see it!)

**When you come back to this, try the Device Console first - it's the most reliable!**

