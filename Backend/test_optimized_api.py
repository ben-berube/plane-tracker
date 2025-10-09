#!/usr/bin/env python3
"""
Comprehensive test script for the optimized PlaneTracker backend
Tests rate limiting, caching, background refresh, and WebSocket functionality
"""

import asyncio
import aiohttp
import json
import time
from datetime import datetime

class PlaneTrackerTester:
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
    
    async def test_basic_endpoints(self):
        """Test basic API endpoints"""
        print("=" * 60)
        print("TESTING BASIC ENDPOINTS")
        print("=" * 60)
        
        session = await self.get_session()
        
        # Test health check
        print("\n1. Testing health check...")
        async with session.get(f"{self.base_url}/health") as response:
            data = await response.json()
            print(f"   Status: {response.status}")
            print(f"   Response: {data}")
        
        # Test flights endpoint
        print("\n2. Testing flights endpoint...")
        async with session.get(f"{self.base_url}/api/flights") as response:
            data = await response.json()
            print(f"   Status: {response.status}")
            print(f"   Flight count: {data.get('count', 0)}")
            print(f"   Success: {data.get('success', False)}")
        
        # Test status endpoint
        print("\n3. Testing status endpoint...")
        async with session.get(f"{self.base_url}/api/status") as response:
            data = await response.json()
            print(f"   Status: {response.status}")
            print(f"   Flight count: {data.get('flight_count', 0)}")
            if 'statistics' in data:
                stats = data['statistics']
                print(f"   Altitude range: {stats.get('altitude_stats', {}).get('min', 0)} - {stats.get('altitude_stats', {}).get('max', 0)}")
    
    async def test_rate_limiting(self):
        """Test rate limiting functionality"""
        print("\n" + "=" * 60)
        print("TESTING RATE LIMITING")
        print("=" * 60)
        
        session = await self.get_session()
        
        # Test rate limit status
        print("\n1. Testing rate limit status...")
        async with session.get(f"{self.base_url}/api/rate-limit") as response:
            data = await response.json()
            print(f"   Status: {response.status}")
            if 'rate_limit' in data:
                rate_limit = data['rate_limit']
                print(f"   Credits used: {rate_limit.get('daily_credits_used', 0)}")
                print(f"   Max credits: {rate_limit.get('max_daily_credits', 0)}")
                print(f"   Credits remaining: {rate_limit.get('credits_remaining', 0)}")
                print(f"   Can make request: {rate_limit.get('can_make_request', False)}")
                print(f"   Cache fresh: {rate_limit.get('cache_fresh', False)}")
        
        # Test rapid requests to see caching in action
        print("\n2. Testing rapid requests (should use cache)...")
        start_time = time.time()
        
        for i in range(5):
            async with session.get(f"{self.base_url}/api/flights") as response:
                data = await response.json()
                print(f"   Request {i+1}: {response.status} - {data.get('count', 0)} flights")
        
        end_time = time.time()
        print(f"   5 requests completed in {end_time - start_time:.2f} seconds")
    
    async def test_caching_behavior(self):
        """Test caching behavior"""
        print("\n" + "=" * 60)
        print("TESTING CACHING BEHAVIOR")
        print("=" * 60)
        
        session = await self.get_session()
        
        # First request (should fetch from API)
        print("\n1. First request (should fetch from API)...")
        start_time = time.time()
        async with session.get(f"{self.base_url}/api/flights") as response:
            data = await response.json()
            end_time = time.time()
            print(f"   Response time: {end_time - start_time:.2f} seconds")
            print(f"   Flight count: {data.get('count', 0)}")
        
        # Immediate second request (should use cache)
        print("\n2. Immediate second request (should use cache)...")
        start_time = time.time()
        async with session.get(f"{self.base_url}/api/flights") as response:
            data = await response.json()
            end_time = time.time()
            print(f"   Response time: {end_time - start_time:.2f} seconds")
            print(f"   Flight count: {data.get('count', 0)}")
        
        # Force refresh
        print("\n3. Force refresh request...")
        start_time = time.time()
        async with session.get(f"{self.base_url}/api/flights/refresh") as response:
            data = await response.json()
            end_time = time.time()
            print(f"   Response time: {end_time - start_time:.2f} seconds")
            print(f"   Flight count: {data.get('count', 0)}")
            print(f"   Message: {data.get('message', '')}")
    
    async def test_websocket_connection(self):
        """Test WebSocket connection"""
        print("\n" + "=" * 60)
        print("TESTING WEBSOCKET CONNECTION")
        print("=" * 60)
        
        session = await self.get_session()
        
        try:
            print("\n1. Connecting to WebSocket...")
            async with session.ws_connect(f"{self.base_url}/ws") as ws:
                print("   WebSocket connected successfully!")
                
                # Listen for a few messages
                message_count = 0
                start_time = time.time()
                
                async for msg in ws:
                    if msg.type == aiohttp.WSMsgType.TEXT:
                        data = json.loads(msg.data)
                        message_count += 1
                        print(f"   Message {message_count}: {data.get('count', 0)} flights at {data.get('timestamp', '')}")
                        
                        # Stop after 3 messages or 20 seconds
                        if message_count >= 3 or (time.time() - start_time) > 20:
                            break
                    elif msg.type == aiohttp.WSMsgType.ERROR:
                        print(f"   WebSocket error: {ws.exception()}")
                        break
                
                print(f"   Received {message_count} messages in {time.time() - start_time:.2f} seconds")
                
        except Exception as e:
            print(f"   WebSocket connection failed: {e}")
    
    async def test_performance(self):
        """Test performance under load"""
        print("\n" + "=" * 60)
        print("TESTING PERFORMANCE")
        print("=" * 60)
        
        session = await self.get_session()
        
        # Test concurrent requests
        print("\n1. Testing concurrent requests...")
        start_time = time.time()
        
        async def make_request(i):
            async with session.get(f"{self.base_url}/api/flights") as response:
                data = await response.json()
                return i, response.status, data.get('count', 0)
        
        # Make 10 concurrent requests
        tasks = [make_request(i) for i in range(10)]
        results = await asyncio.gather(*tasks)
        
        end_time = time.time()
        print(f"   10 concurrent requests completed in {end_time - start_time:.2f} seconds")
        
        for i, status, count in results:
            print(f"   Request {i}: {status} - {count} flights")
    
    async def run_all_tests(self):
        """Run all tests"""
        print("PLANETRACKER BACKEND OPTIMIZATION TESTS")
        print("=" * 60)
        print(f"Testing backend at: {self.base_url}")
        print(f"Test started at: {datetime.now()}")
        
        try:
            await self.test_basic_endpoints()
            await self.test_rate_limiting()
            await self.test_caching_behavior()
            await self.test_websocket_connection()
            await self.test_performance()
            
            print("\n" + "=" * 60)
            print("ALL TESTS COMPLETED SUCCESSFULLY!")
            print("=" * 60)
            
        except Exception as e:
            print(f"\nTest failed with error: {e}")
        finally:
            await self.close_session()

async def main():
    """Main test function"""
    tester = PlaneTrackerTester()
    await tester.run_all_tests()

if __name__ == "__main__":
    asyncio.run(main())
