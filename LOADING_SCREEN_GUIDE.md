# Loading Screen Implementation Guide

## ✅ What Was Implemented

### Backend Scripts (NEW)
1. **`Backend/start_backend.sh`** - Kills any process on port 8000 and starts fresh
2. **`Backend/test_connection.sh`** - Tests backend health and flight data

### iOS App (MINIMAL CHANGES)
1. **NEW FILE:** `PlaneTrackerApp/Views/LoadingViewController.swift` - Loading screen
2. **MODIFIED:** `PlaneTrackerApp/SceneDelegate.swift` - Changed 1 line to show loading screen first

**No changes to:** ARView.swift, BackendService.swift, or any other existing code

---

## How to Use

### Step 1: Start Backend

```bash
cd /Users/bberube/Documents/Projects/plane-tracker
./Backend/start_backend.sh
```

**What this does:**
- Kills any existing Python process on port 8000
- Activates the virtual environment
- Starts the backend server
- You should see: "Server started at http://0.0.0.0:8000"

### Step 2: Test Backend (Optional but Recommended)

```bash
./Backend/test_connection.sh
```

**Expected output:**
```
Testing backend connection...
 ✅ Backend healthy
✅ 9 flights available
```

If you see errors, restart the backend with Step 1.

### Step 3: Build and Run iOS App

1. Open Xcode
2. Select your iPhone as target
3. Press Cmd+R to build and run

**What you'll see:**

1. **Loading Screen appears** with:
   - "Connecting to backend..."
   - Backend URL shown below

2. **After 1-2 seconds:**
   - "Found 9 flights" (or actual count)
   - "in SF Bay Area"

3. **After 3 more seconds:**
   - Automatically transitions to AR camera view

---

## What the Loading Screen Tells You

### ✅ Success Messages

| Message | Meaning |
|---------|---------|
| "Connecting..." | App is trying to reach backend |
| "Found X flights" | Backend responded with data! |
| "in SF Bay Area" | Data is being processed |
| → AR View | Everything working, showing AR camera |

### ❌ Error Messages

| Message | What to Check |
|---------|---------------|
| "Connection Error" + details | Backend not running - run `./Backend/start_backend.sh` |
| "Invalid URL" | IP address issue (shouldn't happen with Tailscale) |
| "No data received" | Backend running but not responding - check backend logs |
| "Failed to decode" | Backend returning wrong format - restart backend |

---

## Troubleshooting

### Backend Not Starting

```bash
# Check if something is already on port 8000
lsof -i:8000

# Kill it manually
lsof -ti:8000 | xargs kill -9

# Start backend again
./Backend/start_backend.sh
```

### Loading Screen Stuck on "Connecting..."

**This means the iOS app cannot reach the backend.**

Check:
1. Backend is running: `./Backend/test_connection.sh`
2. Tailscale is active on both devices
3. IP address is still `10.103.2.166`: `tailscale ip -4`

If IP changed, update in `BackendService.swift`:
```swift
return "http://[NEW_IP]:8000"
```

### Loading Screen Shows Error

1. **Stop the app**
2. **Restart backend:** `./Backend/start_backend.sh`
3. **Test connection:** `./Backend/test_connection.sh`
4. **Run app again**

---

## Implementation Details

### LoadingViewController Features

- **Two labels:** Status (large) and Detail (smaller)
- **Auto-refresh:** Subscribes to BackendService for live updates
- **Error handling:** Shows clear error messages
- **Auto-transition:** Waits 3 seconds after data received, then shows AR view
- **NSLog debugging:** All state changes logged (if you can see console)

### What Happens Behind the Scenes

1. `LoadingViewController` creates its own `BackendService` instance
2. Immediately calls `fetchFlights()`
3. Subscribes to three properties:
   - `$flights` - Updates when flight data arrives
   - `$errorMessage` - Shows errors
   - `$isLoading` - Shows loading state
4. When flights arrive, starts 3-second timer
5. Timer fires → presents `ARView` as full-screen modal
6. AR view takes over

---

## Why This Approach Works

1. **Visual Confirmation:** You can SEE that backend is working
2. **No Console Needed:** Status shown on screen
3. **Error Visibility:** Problems are obvious
4. **Minimal Changes:** Only 1 line changed in existing files
5. **Easy to Revert:** Just change that 1 line back

---

## Next Steps Once Loading Screen Works

Once you see "Found X flights" on the loading screen, you've confirmed:
- ✅ Backend is running
- ✅ Backend has flight data
- ✅ iOS app can connect to backend
- ✅ Data is being fetched and parsed

**Then the AR rendering issue becomes the focus:**

The problem is likely:
1. **Coordinate conversion** - Planes positioned incorrectly
2. **Scale** - Planes too small to see
3. **Distance** - Planes outside visible range

But at least you'll KNOW the data pipeline is working!

---

## Quick Reference

**Start backend:**
```bash
./Backend/start_backend.sh
```

**Test backend:**
```bash
./Backend/test_connection.sh
```

**Check if backend is running:**
```bash
curl http://10.103.2.166:8000/api/health
```

**Kill backend:**
```bash
lsof -ti:8000 | xargs kill -9
```

**Files modified:**
- `Backend/start_backend.sh` (NEW)
- `Backend/test_connection.sh` (NEW)
- `PlaneTrackerApp/Views/LoadingViewController.swift` (NEW)
- `PlaneTrackerApp/SceneDelegate.swift` (1 line changed)

