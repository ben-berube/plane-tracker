#!/usr/bin/env python3
"""
PlaneTracker Backend
Optional Python backend for fetching and filtering flight data
"""

import asyncio
import json
from datetime import datetime
from typing import List, Dict, Any, Optional
import aiohttp
from aiohttp import web
from flights import FlightService

class PlaneTrackerBackend:
    def __init__(self):
        self.flight_service = FlightService()
        
    async def start_server(self, host: str = "localhost", port: int = 8000):
        """Start the backend server"""
        from aiohttp import web
        
        app = web.Application()
        app.router.add_get('/api/flights', self.get_flights)
        app.router.add_get('/api/flights/{flight_id}', self.get_flight)
        app.router.add_get('/health', self.health_check)
        
        runner = web.AppRunner(app)
        await runner.setup()
        site = web.TCPSite(runner, host, port)
        await site.start()
        
        print(f"Server started at http://{host}:{port}")
        return runner
        
    async def get_flights(self, request):
        """Get all flights in SF Bay area"""
        try:
            flights = await self.flight_service.get_sf_bay_flights()
            return web.json_response({
                "success": True,
                "flights": flights,
                "count": len(flights),
                "timestamp": datetime.now().isoformat()
            })
        except Exception as e:
            return web.json_response({
                "success": False,
                "error": str(e)
            }, status=500)
    
    async def get_flight(self, request):
        """Get specific flight by ID"""
        flight_id = request.match_info['flight_id']
        try:
            flight = await self.flight_service.get_flight_by_id(flight_id)
            if flight:
                return web.json_response({
                    "success": True,
                    "flight": flight
                })
            else:
                return web.json_response({
                    "success": False,
                    "error": "Flight not found"
                }, status=404)
        except Exception as e:
            return web.json_response({
                "success": False,
                "error": str(e)
            }, status=500)
    
    async def health_check(self, request):
        """Health check endpoint"""
        return web.json_response({
            "status": "healthy",
            "timestamp": datetime.now().isoformat()
        })

async def main():
    backend = PlaneTrackerBackend()
    runner = await backend.start_server()
    
    try:
        # Keep the server running
        await asyncio.Future()  # Run forever
    except KeyboardInterrupt:
        print("Shutting down server...")
    finally:
        await runner.cleanup()

if __name__ == "__main__":
    asyncio.run(main())
