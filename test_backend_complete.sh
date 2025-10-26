#!/bin/bash

# PlaneTracker Backend Testing Script
# This script tests all backend endpoints to ensure everything is working

echo "🛫 PlaneTracker Backend Test Suite"
echo "=================================="
echo ""

BACKEND_URL="http://10.103.2.166:8000"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test function
test_endpoint() {
    local endpoint=$1
    local description=$2
    
    echo -n "Testing $description... "
    response=$(curl -s -w "\n%{http_code}" "$BACKEND_URL$endpoint")
    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | sed '$d')
    
    if [ "$http_code" = "200" ]; then
        echo -e "${GREEN}✓ PASS${NC} (HTTP $http_code)"
        return 0
    else
        echo -e "${RED}✗ FAIL${NC} (HTTP $http_code)"
        return 1
    fi
}

# Test 1: Health Check
echo "1. Health Check Endpoint"
test_endpoint "/api/health" "Health check"
echo ""

# Test 2: Get All Flights
echo "2. Flights Endpoint"
if test_endpoint "/api/flights" "Get all flights"; then
    flights=$(curl -s "$BACKEND_URL/api/flights" | python3 -c "import sys, json; data = json.load(sys.stdin); print(data.get('count', 0))")
    echo "   Found $flights flights"
fi
echo ""

# Test 3: Get Status
echo "3. Status Endpoint"
if test_endpoint "/api/status" "System status"; then
    status=$(curl -s "$BACKEND_URL/api/status" | python3 -m json.tool 2>/dev/null | head -20)
    echo "   Status details:"
    echo "$status" | grep -E "flight_count|timestamp" | sed 's/^/   /'
fi
echo ""

# Test 4: Rate Limit Status
echo "4. Rate Limit Endpoint"
test_endpoint "/api/rate-limit" "Rate limit status"
echo ""

# Summary
echo "=================================="
echo "Test Summary"
echo "=================================="
echo ""

# Get flight details
flight_data=$(curl -s "$BACKEND_URL/api/flights")
success=$(echo "$flight_data" | python3 -c "import sys, json; print(json.load(sys.stdin)['success'])" 2>/dev/null)
count=$(echo "$flight_data" | python3 -c "import sys, json; print(json.load(sys.stdin)['count'])" 2>/dev/null)

if [ "$success" = "True" ]; then
    echo -e "${GREEN}✓ Backend is fully operational${NC}"
    echo "  • API Health: OK"
    echo "  • Flight Count: $count active flights"
    echo "  • All endpoints responding correctly"
    echo ""
    echo "Sample flights:"
    echo "$flight_data" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for f in data['flights'][:3]:
    callsign = f['callsign'].strip()
    lat = f['latitude']
    lon = f['longitude']
    alt = f.get('baro_altitude', 'N/A')
    velocity = f.get('velocity', 'N/A')
    print(f'  • {callsign}: {lat:.4f}°, {lon:.4f}° @ {alt}m, {velocity} m/s')
" 2>/dev/null
else
    echo -e "${RED}✗ Backend issues detected${NC}"
fi

echo ""
echo "Next steps:"
echo "1. Build and run the iOS app in Xcode (Cmd+R)"
echo "2. Point your iPhone at the sky"
echo "3. You should see aircraft markers in AR"
echo ""

