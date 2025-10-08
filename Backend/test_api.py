#!/usr/bin/env python3
"""
Simple test script to validate OpenSky API access
"""

import asyncio
import aiohttp
import json

async def test_opensky_api():
    """Test direct access to OpenSky API"""
    url = "https://opensky-network.org/api/states/all"
    params = {
        "lamin": 37.4,   # SF Bay min latitude
        "lamax": 38.0,   # SF Bay max latitude  
        "lomin": -122.6, # SF Bay min longitude
        "lomax": -121.8  # SF Bay max longitude
    }
    
    print("Testing OpenSky API...")
    print(f"URL: {url}")
    print(f"Params: {params}")
    print("-" * 50)
    
    try:
        async with aiohttp.ClientSession() as session:
            async with session.get(url, params=params) as response:
                print(f"Status Code: {response.status}")
                
                if response.status == 200:
                    data = await response.json()
                    print(f"Response keys: {list(data.keys())}")
                    
                    if 'states' in data and data['states']:
                        print(f"Number of flights found: {len(data['states'])}")
                        print("\nFirst flight sample:")
                        first_flight = data['states'][0]
                        print(f"ICAO24: {first_flight[0]}")
                        print(f"Callsign: {first_flight[1]}")
                        print(f"Country: {first_flight[2]}")
                        print(f"Latitude: {first_flight[6]}")
                        print(f"Longitude: {first_flight[5]}")
                        print(f"Altitude: {first_flight[7]}")
                        print(f"Velocity: {first_flight[9]}")
                    else:
                        print("No flights found in SF Bay area")
                else:
                    print(f"Error: {response.status}")
                    text = await response.text()
                    print(f"Response: {text}")
                    
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    asyncio.run(test_opensky_api())
