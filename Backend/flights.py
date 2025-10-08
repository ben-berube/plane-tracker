"""
Flight data service for fetching and filtering flights
"""

import asyncio
import aiohttp
import json
from typing import List, Dict, Any, Optional
from datetime import datetime, timedelta

class FlightService:
    def __init__(self):
        self.base_url = "https://opensky-network.org/api"
        self.session: Optional[aiohttp.ClientSession] = None
        
        # San Francisco Bay Area bounds
        self.sf_bay_bounds = {
            "lamin": 37.4,  # Minimum latitude
            "lamax": 38.0,  # Maximum latitude
            "lomin": -122.6,  # Minimum longitude
            "lomax": -121.8   # Maximum longitude
        }
    
    async def get_session(self):
        """Get or create aiohttp session"""
        if self.session is None or self.session.closed:
            self.session = aiohttp.ClientSession()
        return self.session
    
    async def close_session(self):
        """Close the aiohttp session"""
        if self.session and not self.session.closed:
            await self.session.close()
    
    async def get_sf_bay_flights(self) -> List[Dict[str, Any]]:
        """Fetch flights in the San Francisco Bay Area"""
        session = await self.get_session()
        
        url = f"{self.base_url}/states/all"
        params = self.sf_bay_bounds.copy()
        
        try:
            async with session.get(url, params=params) as response:
                if response.status == 200:
                    data = await response.json()
                    return self._parse_flight_data(data)
                else:
                    print(f"Error fetching flights: {response.status}")
                    return []
        except Exception as e:
            print(f"Error fetching flights: {e}")
            return []
    
    async def get_flight_by_id(self, flight_id: str) -> Optional[Dict[str, Any]]:
        """Get specific flight by ICAO24 ID"""
        flights = await self.get_sf_bay_flights()
        for flight in flights:
            if flight.get("icao24") == flight_id:
                return flight
        return None
    
    def _parse_flight_data(self, data: Dict[str, Any]) -> List[Dict[str, Any]]:
        """Parse OpenSky API response into flight objects"""
        flights = []
        
        if "states" not in data or not data["states"]:
            return flights
        
        for state in data["states"]:
            if len(state) < 17:
                continue
                
            flight = {
                "icao24": state[0],
                "callsign": state[1].strip() if state[1] else "",
                "origin_country": state[2],
                "time_position": state[3],
                "last_contact": state[4],
                "longitude": state[5],
                "latitude": state[6],
                "baro_altitude": state[7],
                "on_ground": state[8],
                "velocity": state[9],
                "true_track": state[10],
                "vertical_rate": state[11],
                "sensors": state[12],
                "geo_altitude": state[13],
                "squawk": state[14],
                "spi": state[15],
                "position_source": state[16]
            }
            
            # Filter out invalid flights
            if self._is_valid_flight(flight):
                flights.append(flight)
        
        return flights
    
    def _is_valid_flight(self, flight: Dict[str, Any]) -> bool:
        """Check if flight data is valid and relevant"""
        # Must have position data
        if flight["latitude"] is None or flight["longitude"] is None:
            return False
        
        # Must not be on ground (we want airborne flights)
        if flight["on_ground"]:
            return False
        
        # Must have a callsign (identifiable aircraft)
        if not flight["callsign"]:
            return False
        
        # Must be within reasonable altitude range
        altitude = flight["baro_altitude"] or flight["geo_altitude"]
        if altitude is None or altitude < 100:  # Below 100 feet
            return False
        
        return True
    
    def filter_flights_by_altitude(self, flights: List[Dict[str, Any]], 
                                 min_altitude: float = 1000,
                                 max_altitude: float = 50000) -> List[Dict[str, Any]]:
        """Filter flights by altitude range"""
        filtered = []
        for flight in flights:
            altitude = flight["baro_altitude"] or flight["geo_altitude"]
            if altitude and min_altitude <= altitude <= max_altitude:
                filtered.append(flight)
        return filtered
    
    def filter_flights_by_airline(self, flights: List[Dict[str, Any]], 
                                airline_codes: List[str]) -> List[Dict[str, Any]]:
        """Filter flights by airline codes (first 2-3 characters of callsign)"""
        filtered = []
        for flight in flights:
            callsign = flight["callsign"]
            if callsign:
                for code in airline_codes:
                    if callsign.startswith(code):
                        filtered.append(flight)
                        break
        return filtered
    
    def get_flight_statistics(self, flights: List[Dict[str, Any]]) -> Dict[str, Any]:
        """Get statistics about the flights"""
        if not flights:
            return {}
        
        altitudes = []
        velocities = []
        countries = {}
        
        for flight in flights:
            altitude = flight["baro_altitude"] or flight["geo_altitude"]
            if altitude:
                altitudes.append(altitude)
            
            if flight["velocity"]:
                velocities.append(flight["velocity"])
            
            country = flight["origin_country"]
            countries[country] = countries.get(country, 0) + 1
        
        return {
            "total_flights": len(flights),
            "altitude_stats": {
                "min": min(altitudes) if altitudes else 0,
                "max": max(altitudes) if altitudes else 0,
                "avg": sum(altitudes) / len(altitudes) if altitudes else 0
            },
            "velocity_stats": {
                "min": min(velocities) if velocities else 0,
                "max": max(velocities) if velocities else 0,
                "avg": sum(velocities) / len(velocities) if velocities else 0
            },
            "countries": countries
        }
