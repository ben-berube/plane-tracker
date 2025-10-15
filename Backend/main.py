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
        self._background_task = None
        
    async def start_server(self, host: str = "0.0.0.0", port: int = 8000):
        """Start the backend server"""
        from aiohttp import web
        
        app = web.Application()
        
        # Add CORS middleware
        @web.middleware
        async def cors_middleware(request, handler):
            # Handle preflight OPTIONS requests
            if request.method == 'OPTIONS':
                response = web.Response()
            else:
                response = await handler(request)
            
            # Add CORS headers to all responses
            response.headers['Access-Control-Allow-Origin'] = '*'
            response.headers['Access-Control-Allow-Methods'] = 'GET, POST, OPTIONS'
            response.headers['Access-Control-Allow-Headers'] = 'Content-Type, Authorization, X-Requested-With'
            response.headers['Access-Control-Max-Age'] = '86400'
            response.headers['Access-Control-Allow-Credentials'] = 'false'
            
            return response
        
        app.middlewares.append(cors_middleware)
        
        app.router.add_get('/api/flights', self.get_flights)
        app.router.add_get('/api/flights/{flight_id}', self.get_flight)
        app.router.add_get('/api/flights/refresh', self.refresh_flights)
        app.router.add_get('/api/flights/{flight_id}/trajectory', self.get_flight_trajectory)
        app.router.add_get('/api/flights/{flight_id}/altitude', self.get_altitude_prediction)
        app.router.add_get('/api/status', self.get_status)
        app.router.add_get('/api/rate-limit', self.get_rate_limit_status)
        app.router.add_get('/ws', self.websocket_handler)
        app.router.add_get('/api/health', self.health_check)  # Fixed: moved to /api/health
        
        # Add OPTIONS handlers for CORS preflight
        app.router.add_options('/api/flights', self.handle_options)
        app.router.add_options('/api/health', self.handle_options)
        app.router.add_options('/api/flights/{flight_id}', self.handle_options)
        
        # Start background refresh task
        self._background_task = asyncio.create_task(self._background_refresh())
        
        runner = web.AppRunner(app)
        await runner.setup()
        site = web.TCPSite(runner, host, port)
        await site.start()
        
        print(f"Server started at http://{host}:{port}")
        print("Background refresh task started (8-second intervals)")
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
    
    async def refresh_flights(self, request):
        """Force refresh flights data"""
        try:
            flights = await self.flight_service.force_refresh()
            return web.json_response({
                "success": True,
                "flights": flights,
                "count": len(flights),
                "timestamp": datetime.now().isoformat(),
                "message": "Data refreshed successfully"
            })
        except Exception as e:
            return web.json_response({
                "success": False,
                "error": str(e)
            }, status=500)
    
    async def get_status(self, request):
        """Get system status and flight statistics"""
        try:
            flights = await self.flight_service.get_sf_bay_flights()
            stats = self.flight_service.get_flight_statistics(flights)
            rate_limit = self.flight_service.get_rate_limit_status()
            
            return web.json_response({
                "success": True,
                "timestamp": datetime.now().isoformat(),
                "flight_count": len(flights),
                "statistics": stats,
                "rate_limit": rate_limit
            })
        except Exception as e:
            return web.json_response({
                "success": False,
                "error": str(e)
            }, status=500)
    
    async def get_flight_trajectory(self, request):
        """Get predicted trajectory for a specific flight"""
        flight_id = request.match_info['flight_id']
        prediction_time = float(request.query.get('time', 60.0))
        
        try:
            result = await self.flight_service.get_flight_trajectory(flight_id, prediction_time)
            return web.json_response(result)
        except Exception as e:
            return web.json_response({
                "success": False,
                "error": str(e)
            }, status=500)
    
    async def get_altitude_prediction(self, request):
        """Get altitude prediction for a specific flight"""
        flight_id = request.match_info['flight_id']
        
        try:
            result = await self.flight_service.get_altitude_prediction(flight_id)
            return web.json_response(result)
        except Exception as e:
            return web.json_response({
                "success": False,
                "error": str(e)
            }, status=500)
    
    async def get_rate_limit_status(self, request):
        """Get rate limit status"""
        try:
            rate_limit = self.flight_service.get_rate_limit_status()
            return web.json_response({
                "success": True,
                "rate_limit": rate_limit,
                "timestamp": datetime.now().isoformat()
            })
        except Exception as e:
            return web.json_response({
                "success": False,
                "error": str(e)
            }, status=500)
    
    async def websocket_handler(self, request):
        """WebSocket handler for real-time flight updates"""
        ws = web.WebSocketResponse()
        await ws.prepare(request)
        
        print(f"WebSocket connection established from {request.remote}")
        
        try:
            while True:
                # Send flight data every 5 seconds
                flights = await self.flight_service.get_sf_bay_flights()
                rate_limit = self.flight_service.get_rate_limit_status()
                
                await ws.send_json({
                    "type": "flights_update",
                    "flights": flights,
                    "count": len(flights),
                    "rate_limit": rate_limit,
                    "timestamp": datetime.now().isoformat()
                })
                
                await asyncio.sleep(5)  # Send updates every 5 seconds
                
        except Exception as e:
            print(f"WebSocket error: {e}")
        finally:
            print(f"WebSocket connection closed for {request.remote}")
            return ws
    
    async def _background_refresh(self):
        """Background task to keep data fresh"""
        while True:
            try:
                await self.flight_service.get_sf_bay_flights()
                print(f"Background refresh completed at {datetime.now()}")
            except Exception as e:
                print(f"Background refresh error: {e}")
            
            # Refresh every 8 seconds
            await asyncio.sleep(8)
    
    async def health_check(self, request):
        """Health check endpoint"""
        return web.json_response({
            "status": "healthy",
            "timestamp": datetime.now().isoformat()
        })
    
    async def handle_options(self, request):
        """Handle CORS preflight OPTIONS requests"""
        return web.Response(headers={
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
            'Access-Control-Allow-Headers': 'Content-Type, Authorization, X-Requested-With',
            'Access-Control-Max-Age': '86400',
            'Access-Control-Allow-Credentials': 'false'
        })

async def main():
    backend = PlaneTrackerBackend()
    runner = await backend.start_server()
    
    try:
        # Keep the server running
        await asyncio.Future()  # Run forever
    except KeyboardInterrupt:
        print("Shutting down server...")
        if backend._background_task:
            backend._background_task.cancel()
        await backend.flight_service.close_session()
    finally:
        await runner.cleanup()

if __name__ == "__main__":
    asyncio.run(main())
