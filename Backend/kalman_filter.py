"""
Kalman Filter implementation for altitude estimation and flight trajectory prediction
"""

import numpy as np
import math
from typing import Optional, List, Tuple, Dict, Any
from datetime import datetime, timedelta

class AltitudeKalmanFilter:
    """Kalman filter for altitude estimation with vertical rate integration"""
    
    def __init__(self, flight_id: str):
        self.flight_id = flight_id
        # State vector: [altitude, vertical_velocity]
        self.state = np.array([35000.0, 0.0])  # [altitude, vertical_rate]
        self.covariance = np.array([[1000.0, 0.0], [0.0, 100.0]])  # Initial uncertainty
        
        # Process model matrices
        self.F = np.array([[1.0, 1.0],    # State transition
                          [0.0, 1.0]])
        
        # Measurement model (we measure altitude)
        self.H = np.array([[1.0, 0.0]])  # We only measure altitude
        
        # Process noise (how much we trust our model)
        self.Q = np.array([[1.0, 0.0],   # Altitude process noise
                          [0.0, 0.1]])   # Vertical rate process noise
        
        # Measurement noise (how much we trust measurements)
        self.R = np.array([[100.0]])     # Altitude measurement noise
        
        self.last_update_time = None
        self.measurement_history = []
        self.prediction_history = []
    
    def predict(self, dt: float) -> Tuple[float, float]:
        """Predict next state based on model"""
        # Update state transition matrix with time
        self.F[0, 1] = dt
        
        # Predict state
        self.state = self.F @ self.state
        
        # Predict covariance
        self.covariance = self.F @ self.covariance @ self.F.T + self.Q
        
        # Store prediction
        self.prediction_history.append({
            'time': datetime.now(),
            'altitude': self.state[0],
            'vertical_rate': self.state[1]
        })
        
        return self.state[0], self.state[1]  # altitude, vertical_rate
    
    def update(self, measured_altitude: float, measured_vertical_rate: Optional[float] = None, 
               measurement_uncertainty: Optional[float] = None):
        """Update state with new measurement"""
        current_time = datetime.now()
        
        # Calculate time delta
        if self.last_update_time:
            dt = (current_time - self.last_update_time).total_seconds()
        else:
            dt = 1.0  # Default 1 second
        
        # Predict first
        self.predict(dt)
        
        # Update measurement noise if provided
        if measurement_uncertainty:
            self.R[0, 0] = measurement_uncertainty
        
        # Kalman gain
        S = self.H @ self.covariance @ self.H.T + self.R
        K = self.covariance @ self.H.T @ np.linalg.inv(S)
        
        # Update state
        innovation = measured_altitude - self.H @ self.state
        self.state = self.state + K @ innovation
        
        # Update covariance
        I = np.eye(len(self.state))
        self.covariance = (I - K @ self.H) @ self.covariance
        
        # Update vertical rate if provided
        if measured_vertical_rate is not None:
            self.state[1] = measured_vertical_rate
        
        # Store measurement
        self.measurement_history.append({
            'time': current_time,
            'altitude': measured_altitude,
            'vertical_rate': measured_vertical_rate
        })
        
        self.last_update_time = current_time
        
        return self.state[0], self.state[1]
    
    def get_current_estimate(self) -> Tuple[float, float]:
        """Get current altitude and vertical rate estimate"""
        return self.state[0], self.state[1]
    
    def get_confidence(self) -> float:
        """Get confidence level based on covariance"""
        # Lower covariance = higher confidence
        altitude_variance = self.covariance[0, 0]
        return max(0.0, min(1.0, 1.0 - (altitude_variance / 1000.0)))
    
    def reset(self):
        """Reset filter to initial state"""
        self.state = np.array([35000.0, 0.0])
        self.covariance = np.array([[1000.0, 0.0], [0.0, 100.0]])
        self.last_update_time = None
        self.measurement_history = []
        self.prediction_history = []


class FlightTrajectoryPredictor:
    """Predict flight trajectories using vector arithmetic and aircraft dynamics"""
    
    def __init__(self):
        self.earth_radius = 6371000  # Earth radius in meters
        self.gravity = 9.81  # Gravity constant
        self.standard_atmosphere = self._init_standard_atmosphere()
    
    def _init_standard_atmosphere(self) -> Dict[int, float]:
        """Initialize standard atmosphere model for altitude-based calculations"""
        return {
            0: 101325,      # Sea level pressure (Pa)
            1000: 89875,    # 1km
            2000: 79495,    # 2km
            5000: 54020,    # 5km
            10000: 26436,   # 10km
            15000: 12044,   # 15km
            20000: 5475,    # 20km
            30000: 1172,    # 30km
            40000: 287,     # 40km
        }
    
    def predict_trajectory(self, flight: Dict[str, Any], 
                          prediction_time: float = 60.0, 
                          time_step: float = 2.0) -> List[Dict[str, Any]]:
        """Predict flight trajectory for AR visualization"""
        
        # Current state
        lat = flight["latitude"]
        lon = flight["longitude"]
        alt = flight.get("baro_altitude") or flight.get("geo_altitude") or 35000
        velocity = flight["velocity"] or 0
        track = flight["true_track"] or 0
        vertical_rate = flight["vertical_rate"] or 0
        
        # Convert to 3D position
        current_pos = self._lat_lon_alt_to_3d(lat, lon, alt)
        
        # Calculate velocity vector
        velocity_vector = self._calculate_velocity_vector(velocity, track, vertical_rate)
        
        # Predict trajectory
        trajectory = []
        for t in np.arange(0, prediction_time, time_step):
            # Enhanced kinematic prediction with aircraft dynamics
            predicted_pos = self._predict_position_enhanced(
                current_pos, velocity_vector, t, alt, velocity
            )
            
            # Convert back to lat/lon/alt
            pred_lat, pred_lon, pred_alt = self._3d_to_lat_lon_alt(predicted_pos)
            
            # Calculate additional trajectory properties
            trajectory_point = {
                'latitude': pred_lat,
                'longitude': pred_lon,
                'altitude': pred_alt,
                'time_offset': t,
                'distance_from_current': self._calculate_distance(
                    (lat, lon, alt), (pred_lat, pred_lon, pred_alt)
                ),
                'bearing': self._calculate_bearing(
                    (lat, lon), (pred_lat, pred_lon)
                )
            }
            
            trajectory.append(trajectory_point)
        
        return trajectory
    
    def _lat_lon_alt_to_3d(self, lat: float, lon: float, alt: float) -> np.ndarray:
        """Convert lat/lon/alt to 3D Cartesian coordinates"""
        lat_rad = math.radians(lat)
        lon_rad = math.radians(lon)
        
        # Convert to Cartesian coordinates
        x = (self.earth_radius + alt) * math.cos(lat_rad) * math.cos(lon_rad)
        y = (self.earth_radius + alt) * math.cos(lat_rad) * math.sin(lon_rad)
        z = (self.earth_radius + alt) * math.sin(lat_rad)
        
        return np.array([x, y, z])
    
    def _3d_to_lat_lon_alt(self, pos: np.ndarray) -> Tuple[float, float, float]:
        """Convert 3D Cartesian coordinates to lat/lon/alt"""
        x, y, z = pos
        
        # Calculate latitude and longitude
        lat = math.degrees(math.asin(z / np.linalg.norm(pos)))
        lon = math.degrees(math.atan2(y, x))
        
        # Calculate altitude
        alt = np.linalg.norm(pos) - self.earth_radius
        
        return lat, lon, alt
    
    def _calculate_velocity_vector(self, velocity: float, track: float, vertical_rate: float) -> np.ndarray:
        """Calculate 3D velocity vector from speed, track, and vertical rate"""
        # Horizontal velocity components (m/s)
        track_rad = math.radians(track)
        v_north = velocity * math.cos(track_rad)  # North component
        v_east = velocity * math.sin(track_rad)   # East component
        
        # Vertical velocity (m/s)
        v_up = vertical_rate
        
        return np.array([v_north, v_east, v_up])
    
    def _predict_position_enhanced(self, initial_pos: np.ndarray, velocity_vector: np.ndarray, 
                                 time: float, altitude: float, speed: float) -> np.ndarray:
        """Enhanced position prediction with aircraft dynamics"""
        # Simple constant velocity model with altitude-based adjustments
        predicted_pos = initial_pos + velocity_vector * time
        
        # Apply altitude-based corrections
        altitude_factor = self._get_altitude_correction_factor(altitude)
        predicted_pos = predicted_pos * altitude_factor
        
        # Ensure we stay on Earth's surface
        distance_from_center = np.linalg.norm(predicted_pos)
        if distance_from_center < self.earth_radius:
            # Project back to Earth's surface
            predicted_pos = predicted_pos * (self.earth_radius / distance_from_center)
        
        return predicted_pos
    
    def _get_altitude_correction_factor(self, altitude: float) -> float:
        """Get correction factor based on altitude for trajectory prediction"""
        if altitude < 1000:
            return 1.0  # Ground level
        elif altitude < 5000:
            return 1.001  # Low altitude
        elif altitude < 15000:
            return 1.002  # Medium altitude
        elif altitude < 30000:
            return 1.003  # High altitude
        else:
            return 1.004  # Very high altitude
    
    def _calculate_distance(self, pos1: Tuple[float, float, float], 
                           pos2: Tuple[float, float, float]) -> float:
        """Calculate 3D distance between two points"""
        lat1, lon1, alt1 = pos1
        lat2, lon2, alt2 = pos2
        
        # Haversine formula for horizontal distance
        lat1_rad = math.radians(lat1)
        lat2_rad = math.radians(lat2)
        dlat = math.radians(lat2 - lat1)
        dlon = math.radians(lon2 - lon1)
        
        a = (math.sin(dlat/2)**2 + 
             math.cos(lat1_rad) * math.cos(lat2_rad) * math.sin(dlon/2)**2)
        c = 2 * math.asin(math.sqrt(a))
        
        horizontal_distance = self.earth_radius * c
        
        # Vertical distance
        vertical_distance = abs(alt2 - alt1)
        
        # 3D distance
        return math.sqrt(horizontal_distance**2 + vertical_distance**2)
    
    def _calculate_bearing(self, pos1: Tuple[float, float], pos2: Tuple[float, float]) -> float:
        """Calculate bearing between two points"""
        lat1, lon1 = pos1
        lat2, lon2 = pos2
        
        lat1_rad = math.radians(lat1)
        lat2_rad = math.radians(lat2)
        dlon_rad = math.radians(lon2 - lon1)
        
        y = math.sin(dlon_rad) * math.cos(lat2_rad)
        x = (math.cos(lat1_rad) * math.sin(lat2_rad) - 
             math.sin(lat1_rad) * math.cos(lat2_rad) * math.cos(dlon_rad))
        
        bearing = math.atan2(y, x)
        return math.degrees(bearing)
    
    def calculate_trajectory_for_ar(self, flight: Dict[str, Any], 
                                  camera_position: Tuple[float, float, float],
                                  camera_orientation: Tuple[float, float, float],
                                  field_of_view: float = 60.0) -> List[Dict[str, Any]]:
        """Calculate trajectory points visible in camera field of view"""
        
        # Get predicted trajectory
        trajectory = self.predict_trajectory(flight)
        
        # Filter points within camera view
        visible_points = []
        for point in trajectory:
            # Convert to 3D position
            point_3d = self._lat_lon_alt_to_3d(
                point['latitude'], point['longitude'], point['altitude']
            )
            
            # Check if point is within camera field of view
            if self._is_point_in_camera_view(point_3d, camera_position, camera_orientation, field_of_view):
                visible_points.append(point)
        
        return visible_points
    
    def _is_point_in_camera_view(self, point_3d: np.ndarray, 
                                camera_pos: Tuple[float, float, float],
                                camera_orientation: Tuple[float, float, float],
                                fov: float) -> bool:
        """Check if 3D point is within camera field of view"""
        # Calculate vector from camera to point
        camera_to_point = point_3d - np.array(camera_pos)
        
        # Calculate angle between camera direction and point
        camera_direction = np.array(camera_orientation)
        angle = math.acos(np.dot(camera_to_point, camera_direction) / 
                         (np.linalg.norm(camera_to_point) * np.linalg.norm(camera_direction)))
        
        # Check if within field of view
        return math.degrees(angle) <= fov / 2
