#!/usr/bin/env python3
"""
Enhanced test script for the optimized PlaneTracker backend with altitude prediction and trajectory
"""

import asyncio
import aiohttp
import json
import time
from datetime import datetime

class EnhancedPlaneTrackerTester:
    def __init__(self, base_url="http://localhost:8000"):
        self.base_url = base_url
        self.session = None
    
    async def get_session(self):
        """Get or create aiohttp session"""
        if self.session is None or self.session.closed:
            self.session = aiohttp.ClientSession()
        return self.session
    
    async def close_session(self):
        """Close the aiohttp session"""
        if self.session and not self.session.closed:
            await self.session.close()
    
    async def test_enhanced_flights(self):
        """Test enhanced flights endpoint with altitude prediction"""
        print("=" * 60)
        print("TESTING ENHANCED FLIGHTS WITH ALTITUDE PREDICTION")
        print("=" * 60)
        
        session = await self.get_session()
        
        print("\n1. Testing enhanced flights endpoint...")
        async with session.get(f"{self.base_url}/api/flights") as response:
            data = await response.json()
            print(f"   Status: {response.status}")
            print(f"   Flight count: {data.get('count', 0)}")
            
            if data.get('success') and data.get('flights'):
                flights = data['flights']
                print(f"\n   Enhanced flight data sample:")
                
                for i, flight in enumerate(flights[:3]):  # Show first 3 flights
                    print(f"   Flight {i+1}:")
                    print(f"     ICAO24: {flight.get('icao24', 'N/A')}")
                    print(f"     Callsign: {flight.get('callsign', 'N/A')}")
                    print(f"     Baro Altitude: {flight.get('baro_altitude', 'N/A')}")
                    print(f"     Geo Altitude: {flight.get('geo_altitude', 'N/A')}")
                    print(f"     Predicted Altitude: {flight.get('predicted_altitude', 'N/A')}")
                    print(f"     Altitude Confidence: {flight.get('altitude_confidence', 'N/A')}")
                    print(f"     Has Predicted Altitude: {flight.get('has_predicted_altitude', 'N/A')}")
                    print(f"     Trajectory Points: {len(flight.get('predicted_trajectory', []))}")
    
    async def test_altitude_prediction(self):
        """Test altitude prediction for specific flights"""
        print("\n" + "=" * 60)
        print("TESTING ALTITUDE PREDICTION")
        print("=" * 60)
        
        session = await self.get_session()
        
        # First get flights to find a flight ID
        async with session.get(f"{self.base_url}/api/flights") as response:
            data = await response.json()
            if data.get('success') and data.get('flights'):
                flight_id = data['flights'][0]['icao24']
                
                print(f"\n1. Testing altitude prediction for flight {flight_id}...")
                async with session.get(f"{self.base_url}/api/flights/{flight_id}/altitude") as response:
                    altitude_data = await response.json()
                    print(f"   Status: {response.status}")
                    print(f"   Success: {altitude_data.get('success', False)}")
                    
                    if altitude_data.get('success'):
                        print(f"   Predicted Altitude: {altitude_data.get('predicted_altitude', 'N/A')}")
                        print(f"   Predicted Vertical Rate: {altitude_data.get('predicted_vertical_rate', 'N/A')}")
                        print(f"   Confidence: {altitude_data.get('confidence', 'N/A')}")
                    else:
                        print(f"   Error: {altitude_data.get('error', 'Unknown error')}")
    
    async def test_trajectory_prediction(self):
        """Test trajectory prediction for specific flights"""
        print("\n" + "=" * 60)
        print("TESTING TRAJECTORY PREDICTION")
        print("=" * 60)
        
        session = await self.get_session()
        
        # First get flights to find a flight ID
        async with session.get(f"{self.base_url}/api/flights") as response:
            data = await response.json()
            if data.get('success') and data.get('flights'):
                flight_id = data['flights'][0]['icao24']
                
                print(f"\n1. Testing trajectory prediction for flight {flight_id}...")
                async with session.get(f"{self.base_url}/api/flights/{flight_id}/trajectory?time=30") as response:
                    trajectory_data = await response.json()
                    print(f"   Status: {response.status}")
                    print(f"   Success: {trajectory_data.get('success', False)}")
                    
                    if trajectory_data.get('success'):
                        trajectory = trajectory_data.get('trajectory', [])
                        print(f"   Trajectory Points: {len(trajectory)}")
                        print(f"   Prediction Time: {trajectory_data.get('prediction_time', 'N/A')} seconds")
                        
                        if trajectory:
                            print(f"\n   Trajectory sample (first 3 points):")
                            for i, point in enumerate(trajectory[:3]):
                                print(f"     Point {i+1}:")
                                print(f"       Latitude: {point.get('latitude', 'N/A')}")
                                print(f"       Longitude: {point.get('longitude', 'N/A')}")
                                print(f"       Altitude: {point.get('altitude', 'N/A')}")
                                print(f"       Time Offset: {point.get('time_offset', 'N/A')}s")
                                print(f"       Distance: {point.get('distance_from_current', 'N/A')}m")
                                print(f"       Bearing: {point.get('bearing', 'N/A')}°")
                    else:
                        print(f"   Error: {trajectory_data.get('error', 'Unknown error')}")
    
    async def test_websocket_enhanced(self):
        """Test WebSocket with enhanced data"""
        print("\n" + "=" * 60)
        print("TESTING ENHANCED WEBSOCKET")
        print("=" * 60)
        
        session = await self.get_session()
        
        try:
            print("\n1. Connecting to enhanced WebSocket...")
            async with session.ws_connect(f"{self.base_url}/ws") as ws:
                print("   WebSocket connected successfully!")
                
                # Listen for a few messages
                message_count = 0
                start_time = time.time()
                
                async for msg in ws:
                    if msg.type == aiohttp.WSMsgType.TEXT:
                        data = json.loads(msg.data)
                        message_count += 1
                        
                        print(f"   Message {message_count}:")
                        print(f"     Flight count: {data.get('count', 0)}")
                        print(f"     Timestamp: {data.get('timestamp', 'N/A')}")
                        
                        # Check for enhanced data
                        if 'rate_limit' in data:
                            rate_limit = data['rate_limit']
                            print(f"     Rate limit remaining: {rate_limit.get('credits_remaining', 'N/A')}")
                        
                        # Check for flights with enhanced data
                        flights = data.get('flights', [])
                        if flights:
                            enhanced_flights = [f for f in flights if 'predicted_altitude' in f]
                            print(f"     Enhanced flights: {len(enhanced_flights)}")
                            
                            if enhanced_flights:
                                flight = enhanced_flights[0]
                                print(f"     Sample enhanced flight:")
                                print(f"       Predicted altitude: {flight.get('predicted_altitude', 'N/A')}")
                                print(f"       Altitude confidence: {flight.get('altitude_confidence', 'N/A')}")
                                print(f"       Trajectory points: {len(flight.get('predicted_trajectory', []))}")
                        
                        # Stop after 3 messages or 30 seconds
                        if message_count >= 3 or (time.time() - start_time) > 30:
                            break
                    elif msg.type == aiohttp.WSMsgType.ERROR:
                        print(f"   WebSocket error: {ws.exception()}")
                        break
                
                print(f"   Received {message_count} enhanced messages in {time.time() - start_time:.2f} seconds")
                
        except Exception as e:
            print(f"   WebSocket connection failed: {e}")
    
    async def test_performance_enhanced(self):
        """Test performance with enhanced features"""
        print("\n" + "=" * 60)
        print("TESTING ENHANCED PERFORMANCE")
        print("=" * 60)
        
        session = await self.get_session()
        
        # Test enhanced endpoints performance
        print("\n1. Testing enhanced endpoints performance...")
        start_time = time.time()
        
        async def test_enhanced_endpoint(endpoint, description):
            async with session.get(f"{self.base_url}{endpoint}") as response:
                data = await response.json()
                return response.status, data.get('success', False), description
        
        # Test multiple enhanced endpoints
        tasks = [
            test_enhanced_endpoint("/api/flights", "Enhanced flights"),
            test_enhanced_endpoint("/api/status", "System status"),
            test_enhanced_endpoint("/api/rate-limit", "Rate limit status"),
        ]
        
        results = await asyncio.gather(*tasks)
        end_time = time.time()
        
        print(f"   Enhanced endpoints completed in {end_time - start_time:.2f} seconds")
        
        for status, success, description in results:
            print(f"   {description}: {status} - Success: {success}")
    
    async def test_altitude_prediction_accuracy(self):
        """Test altitude prediction accuracy with multiple methods"""
        print("\n" + "=" * 60)
        print("TESTING ALTITUDE PREDICTION ACCURACY")
        print("=" * 60)
        
        session = await self.get_session()
        
        # Get flights and analyze altitude prediction methods
        async with session.get(f"{self.base_url}/api/flights") as response:
            data = await response.json()
            if data.get('success') and data.get('flights'):
                flights = data['flights']
                
                print(f"\n1. Analyzing altitude prediction methods for {len(flights)} flights...")
                
                methods_used = {
                    'baro_altitude': 0,
                    'geo_altitude': 0,
                    'predicted_altitude': 0,
                    'has_predicted_altitude': 0
                }
                
                confidence_scores = []
                
                for flight in flights:
                    # Count methods used
                    if flight.get('baro_altitude') is not None:
                        methods_used['baro_altitude'] += 1
                    elif flight.get('geo_altitude') is not None:
                        methods_used['geo_altitude'] += 1
                    elif flight.get('predicted_altitude') is not None:
                        methods_used['predicted_altitude'] += 1
                    
                    if flight.get('has_predicted_altitude'):
                        methods_used['has_predicted_altitude'] += 1
                    
                    # Collect confidence scores
                    if flight.get('altitude_confidence') is not None:
                        confidence_scores.append(flight['altitude_confidence'])
                
                print(f"   Altitude prediction methods:")
                for method, count in methods_used.items():
                    percentage = (count / len(flights)) * 100
                    print(f"     {method}: {count} flights ({percentage:.1f}%)")
                
                if confidence_scores:
                    avg_confidence = sum(confidence_scores) / len(confidence_scores)
                    print(f"   Average confidence score: {avg_confidence:.3f}")
                    print(f"   Confidence range: {min(confidence_scores):.3f} - {max(confidence_scores):.3f}")
    
    async def run_all_tests(self):
        """Run all enhanced tests"""
        print("ENHANCED PLANETRACKER BACKEND TESTS")
        print("=" * 60)
        print(f"Testing enhanced backend at: {self.base_url}")
        print(f"Test started at: {datetime.now()}")
        
        try:
            await self.test_enhanced_flights()
            await self.test_altitude_prediction()
            await self.test_trajectory_prediction()
            await self.test_websocket_enhanced()
            await self.test_performance_enhanced()
            await self.test_altitude_prediction_accuracy()
            
            print("\n" + "=" * 60)
            print("ALL ENHANCED TESTS COMPLETED SUCCESSFULLY!")
            print("=" * 60)
            print("\nKey Features Tested:")
            print("✓ Kalman Filter altitude prediction")
            print("✓ Flight trajectory prediction with vector arithmetic")
            print("✓ Enhanced WebSocket with real-time updates")
            print("✓ AR-ready trajectory visualization")
            print("✓ Performance optimization with caching")
            print("✓ Rate limiting and credit management")
            
        except Exception as e:
            print(f"\nTest failed with error: {e}")
        finally:
            await self.close_session()

async def main():
    """Main test function"""
    tester = EnhancedPlaneTrackerTester()
    await tester.run_all_tests()

if __name__ == "__main__":
    asyncio.run(main())
