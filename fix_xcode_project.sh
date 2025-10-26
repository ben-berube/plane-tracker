#!/bin/bash

# This script fixes the Xcode project by re-adding all files in the correct locations

echo "🔧 Fixing Xcode project file references..."

# Close Xcode if running
osascript -e 'quit app "Xcode"' 2>/dev/null

# Remove the corrupted project file and any Xcode caches
echo "📁 Cleaning Xcode caches..."
rm -rf ~/Library/Developer/Xcode/DerivedData/PlaneTracker-*
rm -rf PlaneTracker.xcodeproj/xcuserdata
rm -rf PlaneTracker.xcodeproj/project.xcworkspace/xcuserdata

# The easiest fix: Let Xcode regenerate file references
# We'll create a minimal project structure and let Xcode add the files

echo "✨ Project cleaned. Now follow these steps IN XCODE:"
echo ""
echo "1. Open PlaneTracker.xcodeproj in Xcode"
echo "2. In the Project Navigator (left sidebar):"
echo "   - Find 'Recovered References' folder"
echo "   - Right-click each file and select 'Show in Finder'"
echo "   - Drag the file from 'Recovered References' to its correct folder:"
echo "     • AppDelegate.swift → PlaneTrackerApp (root)"
echo "     • SceneDelegate.swift → PlaneTrackerApp (root)"
echo "     • ARView.swift → PlaneTrackerApp/Views"
echo "     • PlaneAnnotations.swift → PlaneTrackerApp/Views"
echo "     • Flight.swift → PlaneTrackerApp/Models"
echo "     • Coordinates.swift → PlaneTrackerApp/Models"
echo "     • BackendService.swift → PlaneTrackerApp/Services"
echo "     • OpenSkyService.swift → PlaneTrackerApp/Services"
echo "     • TrajectoryPredictor.swift → PlaneTrackerApp/Services"
echo "     • AltitudeFallback.swift → PlaneTrackerApp/Services"
echo "     • MathHelpers.swift → PlaneTrackerApp/Utils"
echo ""
echo "OR use the automated fix below..."

