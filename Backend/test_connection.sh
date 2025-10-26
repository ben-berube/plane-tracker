#!/bin/bash
echo "Testing backend connection..."
curl -s http://10.103.2.166:8000/api/health && echo " ✅ Backend healthy" || echo " ❌ Backend not responding"
curl -s http://10.103.2.166:8000/api/flights | python3 -c "import sys, json; d=json.load(sys.stdin); print(f'✅ {d[\"count\"]} flights available')" 2>/dev/null || echo "❌ No flight data"

