"""
Flight data service for fetching and filtering flights with rate limiting and caching
"""

import asyncio
import aiohttp
import json
import time
from typing import List, Dict, Any, Optional
from datetime import datetime, timedelta
from kalman_filter import AltitudeKalmanFilter, FlightTrajectoryPredictor

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
        
        # Rate limiting and caching
        self._cache = None
        self._cache_timestamp = 0
        self._cache_duration = 8  # 8 seconds cache duration (within 15s validity)
        self._last_request_time = 0
        self._min_request_interval = 5  # Minimum 5 seconds between requests (API resolution)
        self._daily_credits_used = 0
        self._max_daily_credits = 4000  # Default, will be updated from headers
        self._rate_limit_remaining = 4000
        self._rate_limit_reset_time = None
        
        # Altitude prediction and trajectory tracking
        self.altitude_filters = {}  # Kalman filters per flight
        self.trajectory_predictor = FlightTrajectoryPredictor()
        self.flight_history = {}  # Track flight history for predictions
    
    async def get_session(self):
        """Get or create aiohttp session"""
        if self.session is None or self.session.closed:
            self.session = aiohttp.ClientSession()
        return self.session
    
    async def close_session(self):
        """Close the aiohttp session"""
        if self.session and not self.session.closed:
            await self.session.close()
    
    async def get_sf_bay_flights(self, force_refresh: bool = False) -> List[Dict[str, Any]]:
        """Fetch flights in the San Francisco Bay Area with intelligent caching"""
        current_time = time.time()
        
        # Return cached data if still fresh and not forcing refresh
        if (not force_refresh and 
            self._cache is not None and 
            current_time - self._cache_timestamp < self._cache_duration):
            return self._cache
        
        # Check rate limiting
        if not self._can_make_request():
            print("Rate limit reached, returning cached data")
            return self._cache or []
        
        # Make API request
        flights = await self._fetch_flights_from_api()
        
        if flights is not None:
            # Update cache
            self._cache = flights
            self._cache_timestamp = current_time
            self._last_request_time = current_time
            return flights
        else:
            # Return stale cache if API request failed
            return self._cache or []
    
    def _can_make_request(self) -> bool:
        """Check if we can make a request based on rate limits"""
        current_time = time.time()
        
        # Check minimum interval between requests
        if current_time - self._last_request_time < self._min_request_interval:
            return False
        
        # Check daily credit limit
        if self._daily_credits_used >= self._max_daily_credits:
            return False
        
        # Check rate limit remaining
        if self._rate_limit_remaining <= 0:
            return False
        
        return True
    
    async def _fetch_flights_from_api(self) -> Optional[List[Dict[str, Any]]]:
        """Fetch flights from OpenSky API with proper error handling"""
        session = await self.get_session()
        
        url = f"{self.base_url}/states/all"
        params = self.sf_bay_bounds.copy()
        
        try:
            async with session.get(url, params=params) as response:
                # Update rate limit info from headers
                self._update_rate_limit_info(response.headers)
                
                if response.status == 200:
                    data = await response.json()
                    flights = self._parse_flight_data(data)
                    self._daily_credits_used += 1
                    return flights
                elif response.status == 429:  # Too Many Requests
                    retry_after = int(response.headers.get('X-Rate-Limit-Retry-After-Seconds', 60))
                    print(f"Rate limit exceeded. Retry after {retry_after} seconds")
                    self._rate_limit_reset_time = time.time() + retry_after
                    return None
                else:
                    print(f"Error fetching flights: {response.status}")
                    return None
        except Exception as e:
            print(f"Error fetching flights: {e}")
            return None
    
    def _update_rate_limit_info(self, headers: Dict[str, str]):
        """Update rate limit information from response headers"""
        try:
            if 'X-Rate-Limit-Remaining' in headers:
                self._rate_limit_remaining = int(headers['X-Rate-Limit-Remaining'])
                
                # If remaining is greater than 4000, we have 8000 credits
                if self._rate_limit_remaining > 4000:
                    self._max_daily_credits = 8000
                else:
                    self._max_daily_credits = 4000
        except (ValueError, KeyError) as e:
            print(f"Error parsing rate limit headers: {e}")
            # Keep existing values if parsing fails
    
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
            
            # Apply altitude prediction and enhancement
            enhanced_flight = self._enhance_flight_data(flight)
            
            # Filter out invalid flights
            if self._is_valid_flight(enhanced_flight):
                flights.append(enhanced_flight)
        
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
    
    def get_rate_limit_status(self) -> Dict[str, Any]:
        """Get current rate limit status"""
        current_time = time.time()
        cache_age = current_time - self._cache_timestamp if self._cache_timestamp else None
        
        return {
            "daily_credits_used": self._daily_credits_used,
            "max_daily_credits": self._max_daily_credits,
            "credits_remaining": self._rate_limit_remaining,
            "can_make_request": self._can_make_request(),
            "cache_age_seconds": cache_age,
            "cache_fresh": cache_age is not None and cache_age < self._cache_duration,
            "next_request_available": max(0, self._min_request_interval - (current_time - self._last_request_time)),
            "rate_limit_reset_time": self._rate_limit_reset_time
        }
    
    async def force_refresh(self) -> List[Dict[str, Any]]:
        """Force a refresh of flight data, bypassing cache"""
        return await self.get_sf_bay_flights(force_refresh=True)
    
    def _enhance_flight_data(self, flight: Dict[str, Any]) -> Dict[str, Any]:
        """Enhance flight data with altitude prediction and trajectory information"""
        flight_id = flight["icao24"]
        
        # Initialize Kalman filter if not exists
        if flight_id not in self.altitude_filters:
            self.altitude_filters[flight_id] = AltitudeKalmanFilter(flight_id)
        
        # Get or initialize flight history
        if flight_id not in self.flight_history:
            self.flight_history[flight_id] = []
        
        # Update flight history
        self.flight_history[flight_id].append(flight)
        if len(self.flight_history[flight_id]) > 10:  # Keep last 10 data points
            self.flight_history[flight_id] = self.flight_history[flight_id][-10:]
        
        # Predict missing altitude
        predicted_altitude = self._predict_missing_altitude(flight, flight_id)
        
        # Add enhanced data to flight
        enhanced_flight = flight.copy()
        enhanced_flight["predicted_altitude"] = predicted_altitude
        enhanced_flight["altitude_confidence"] = self.altitude_filters[flight_id].get_confidence()
        enhanced_flight["has_predicted_altitude"] = (
            flight["baro_altitude"] is None and 
            flight["geo_altitude"] is None
        )
        
        # Add trajectory prediction
        try:
            trajectory = self.trajectory_predictor.predict_trajectory(enhanced_flight)
            enhanced_flight["predicted_trajectory"] = trajectory[:10]  # Next 10 points
        except Exception as e:
            print(f"Trajectory prediction error for {flight_id}: {e}")
            enhanced_flight["predicted_trajectory"] = []
        
        return enhanced_flight
    
    def _predict_missing_altitude(self, flight: Dict[str, Any], flight_id: str) -> float:
        """Predict altitude using Kalman filter and multiple methods"""
        kalman_filter = self.altitude_filters[flight_id]
        flight_history = self.flight_history[flight_id]
        
        # Method 1: Use available altitude data
        if flight["baro_altitude"] is not None and flight["baro_altitude"] > 0:
            kalman_filter.update(flight["baro_altitude"], flight["vertical_rate"])
            return flight["baro_altitude"]
        
        if flight["geo_altitude"] is not None and flight["geo_altitude"] > 0:
            kalman_filter.update(flight["geo_altitude"], flight["vertical_rate"])
            return flight["geo_altitude"]
        
        # Method 2: Kalman filter prediction
        predicted_altitude, predicted_vertical_rate = kalman_filter.predict(1.0)
        if self._is_reasonable_altitude(predicted_altitude):
            return predicted_altitude
        
        # Method 3: Vertical rate integration
        if flight["vertical_rate"] is not None:
            integrated_altitude = self._integrate_vertical_rate(flight, flight_history)
            if self._is_reasonable_altitude(integrated_altitude):
                return integrated_altitude
        
        # Method 4: Velocity-based estimation
        if flight["velocity"] is not None:
            velocity_altitude = self._estimate_from_velocity(flight["velocity"])
            if self._is_reasonable_altitude(velocity_altitude):
                return velocity_altitude
        
        # Method 5: Flight phase analysis
        return self._estimate_from_flight_phase(flight, flight_history)
    
    def _integrate_vertical_rate(self, flight: Dict[str, Any], history: List[Dict[str, Any]]) -> float:
        """Integrate vertical rate over time to predict altitude"""
        if not history:
            return 35000.0  # Default cruising altitude
        
        # Find most recent altitude measurement
        last_altitude = None
        time_since_altitude = 0
        
        for i in range(len(history) - 1, -1, -1):
            prev_flight = history[i]
            if prev_flight["icao24"] == flight["icao24"]:
                if prev_flight["baro_altitude"] is not None:
                    last_altitude = prev_flight["baro_altitude"]
                    break
                elif prev_flight["geo_altitude"] is not None:
                    last_altitude = prev_flight["geo_altitude"]
                    break
                time_since_altitude += 1
        
        if last_altitude is None:
            return 35000.0
        
        # Integrate vertical rate
        vertical_rate = flight["vertical_rate"] or 0.0
        predicted_altitude = last_altitude + (vertical_rate * time_since_altitude)
        
        return max(0, predicted_altitude)  # Don't go below ground
    
    def _estimate_from_velocity(self, velocity: float) -> float:
        """Estimate altitude based on velocity using aircraft performance models"""
        # Commercial aircraft performance curves
        if velocity < 50:      # Taxi/ground
            return 0.0
        elif velocity < 150:   # Takeoff/climb
            return 5000.0
        elif velocity < 250:   # Climb
            return 15000.0
        elif velocity < 350:  # Cruise climb
            return 25000.0
        elif velocity < 450:  # Cruise
            return 35000.0
        else:                 # High altitude cruise
            return 40000.0
    
    def _estimate_from_flight_phase(self, flight: Dict[str, Any], history: List[Dict[str, Any]]) -> float:
        """Estimate altitude based on flight phase analysis"""
        if not history:
            return 35000.0
        
        # Analyze recent trajectory
        recent_positions = []
        for prev_flight in history[-5:]:  # Last 5 data points
            if (prev_flight["icao24"] == flight["icao24"] and 
                prev_flight["latitude"] is not None and 
                prev_flight["longitude"] is not None):
                recent_positions.append((prev_flight["latitude"], prev_flight["longitude"]))
        
        if len(recent_positions) < 2:
            return 35000.0
        
        # Calculate trajectory characteristics
        altitude_change = self._analyze_trajectory(recent_positions, flight)
        
        # Estimate based on trajectory
        if altitude_change > 0.1:  # Climbing
            return 20000.0
        elif altitude_change < -0.1:  # Descending
            return 30000.0
        else:  # Level flight
            return 35000.0
    
    def _analyze_trajectory(self, positions: List[tuple], current_flight: Dict[str, Any]) -> float:
        """Analyze trajectory to determine if climbing/descending"""
        if len(positions) < 2:
            return 0.0
        
        # Calculate bearing changes (simplified)
        bearings = []
        for i in range(1, len(positions)):
            lat1, lon1 = positions[i-1]
            lat2, lon2 = positions[i]
            bearing = self._calculate_bearing(lat1, lon1, lat2, lon2)
            bearings.append(bearing)
        
        # Simple trend analysis
        if len(bearings) < 2:
            return 0.0
        
        # Look for consistent direction changes that might indicate altitude changes
        bearing_changes = [bearings[i] - bearings[i-1] for i in range(1, len(bearings))]
        avg_change = sum(bearing_changes) / len(bearing_changes)
        
        return avg_change
    
    def _calculate_bearing(self, lat1: float, lon1: float, lat2: float, lon2: float) -> float:
        """Calculate bearing between two points"""
        import math
        
        lat1_rad = math.radians(lat1)
        lat2_rad = math.radians(lat2)
        dlon_rad = math.radians(lon2 - lon1)
        
        y = math.sin(dlon_rad) * math.cos(lat2_rad)
        x = (math.cos(lat1_rad) * math.sin(lat2_rad) - 
             math.sin(lat1_rad) * math.cos(lat2_rad) * math.cos(dlon_rad))
        
        bearing = math.atan2(y, x)
        return math.degrees(bearing)
    
    def _is_reasonable_altitude(self, altitude: float) -> bool:
        """Check if altitude is within reasonable bounds"""
        return 0 <= altitude <= 50000
    
    async def get_flight_trajectory(self, flight_id: str, prediction_time: float = 60.0) -> Dict[str, Any]:
        """Get predicted trajectory for a specific flight"""
        flights = await self.get_sf_bay_flights()
        
        for flight in flights:
            if flight["icao24"] == flight_id:
                try:
                    trajectory = self.trajectory_predictor.predict_trajectory(flight, prediction_time)
                    return {
                        "success": True,
                        "flight_id": flight_id,
                        "trajectory": trajectory,
                        "prediction_time": prediction_time,
                        "timestamp": datetime.now().isoformat()
                    }
                except Exception as e:
                    return {
                        "success": False,
                        "error": f"Trajectory prediction failed: {str(e)}"
                    }
        
        return {
            "success": False,
            "error": "Flight not found"
        }
    
    async def get_altitude_prediction(self, flight_id: str) -> Dict[str, Any]:
        """Get altitude prediction for a specific flight"""
        if flight_id not in self.altitude_filters:
            return {
                "success": False,
                "error": "Flight not tracked"
            }
        
        kalman_filter = self.altitude_filters[flight_id]
        altitude, vertical_rate = kalman_filter.get_current_estimate()
        confidence = kalman_filter.get_confidence()
        
        return {
            "success": True,
            "flight_id": flight_id,
            "predicted_altitude": altitude,
            "predicted_vertical_rate": vertical_rate,
            "confidence": confidence,
            "timestamp": datetime.now().isoformat()
        }
    
    async def start_background_refresh(self, interval: int = 8):
        """Start background refresh task"""
        while True:
            try:
                await self.get_sf_bay_flights()
                print(f"Background refresh completed at {datetime.now()}")
            except Exception as e:
                print(f"Background refresh error: {e}")
            
            await asyncio.sleep(interval)
