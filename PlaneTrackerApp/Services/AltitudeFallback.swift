import Foundation
import CoreLocation

class AltitudeFallback {
    
    // Kalman Filter State
    private var altitudeState: [Double] = [35000.0, 0.0]  // [altitude, vertical_rate]
    private var covariance: [[Double]] = [[1000.0, 0.0], [0.0, 100.0]]
    private var lastUpdateTime: Date?
    private var measurementHistory: [(Date, Double, Double?)] = []  // (time, altitude, vertical_rate)
    private var predictionHistory: [(Date, Double, Double)] = []  // (time, altitude, vertical_rate)
    
    // Standard altitude levels for different flight phases
    private let standardAltitudes: [Int] = [1000, 2000, 3000, 4000, 5000, 6000, 7000, 8000, 9000, 10000, 11000, 12000, 13000, 14000, 15000, 16000, 17000, 18000, 19000, 20000, 21000, 22000, 23000, 24000, 25000, 26000, 27000, 28000, 29000, 30000, 31000, 32000, 33000, 34000, 35000, 36000, 37000, 38000, 39000, 40000, 41000, 42000, 43000, 44000, 45000, 46000, 47000, 48000, 49000, 50000]
    
    func estimateAltitude(for flight: Flight, with history: [Flight] = []) -> Double {
        // Method 1: Use backend predicted altitude (highest priority)
        if let predictedAltitude = flight.predictedAltitude, predictedAltitude > 0 {
            updateKalmanFilter(altitude: predictedAltitude, verticalRate: flight.verticalRate)
            return predictedAltitude
        }
        
        // Method 2: Use available altitude data and update Kalman filter
        if let baroAltitude = flight.baroAltitude, baroAltitude > 0 {
            updateKalmanFilter(altitude: baroAltitude, verticalRate: flight.verticalRate)
            return baroAltitude
        }
        
        if let geoAltitude = flight.geoAltitude, geoAltitude > 0 {
            updateKalmanFilter(altitude: geoAltitude, verticalRate: flight.verticalRate)
            return geoAltitude
        }
        
        // If on ground, return 0
        if flight.onGround {
            return 0.0
        }
        
        // Method 3: Kalman Filter Prediction (fallback when backend unavailable)
        if let predictedAltitude = predictAltitudeWithKalman() {
            return predictedAltitude
        }
        
        // Method 4: Vertical Rate Integration
        if let verticalRate = flight.verticalRate {
            let integratedAltitude = integrateVerticalRate(flight: flight, history: history)
            if isReasonableAltitude(integratedAltitude) {
                return integratedAltitude
            }
        }
        
        // Method 5: Velocity-based estimation
        if let velocity = flight.velocity {
            let velocityAltitude = estimateFromVelocity(velocity)
            if isReasonableAltitude(velocityAltitude) {
                return velocityAltitude
            }
        }
        
        // Method 6: Flight phase analysis
        return estimateFromFlightPhase(flight: flight, history: history)
    }
    
    // MARK: - Kalman Filter Methods
    
    private func updateKalmanFilter(altitude: Double, verticalRate: Double?) {
        let now = Date()
        let dt = lastUpdateTime?.timeIntervalSince(now) ?? 1.0
        
        // Predict step
        let F = [[1.0, dt], [0.0, 1.0]]  // State transition matrix
        let Q = [[1.0, 0.0], [0.0, 0.1]] // Process noise
        
        // Update state
        altitudeState[0] = altitudeState[0] + altitudeState[1] * dt
        altitudeState[1] = verticalRate ?? altitudeState[1]
        
        // Update covariance (simplified)
        covariance[0][0] = covariance[0][0] + 1.0
        covariance[1][1] = covariance[1][1] + 0.1
        
        // Store measurement
        measurementHistory.append((now, altitude, verticalRate))
        if measurementHistory.count > 20 {
            measurementHistory.removeFirst()
        }
        
        lastUpdateTime = now
    }
    
    private func predictAltitudeWithKalman() -> Double? {
        guard let lastTime = lastUpdateTime else { return nil }
        
        let dt = Date().timeIntervalSince(lastTime)
        let predictedAltitude = altitudeState[0] + altitudeState[1] * dt
        
        return isReasonableAltitude(predictedAltitude) ? predictedAltitude : nil
    }
    
    private func integrateVerticalRate(flight: Flight, history: [Flight]) -> Double {
        // Find most recent altitude measurement
        var lastAltitude: Double?
        var timeSinceAltitude: Double = 0
        
        for i in stride(from: history.count - 1, through: 0, by: -1) {
            let prevFlight = history[i]
            if prevFlight.id == flight.id {
                if let baroAlt = prevFlight.baroAltitude, baroAlt > 0 {
                    lastAltitude = baroAlt
                    break
                } else if let geoAlt = prevFlight.geoAltitude, geoAlt > 0 {
                    lastAltitude = geoAlt
                    break
                }
                timeSinceAltitude += 1
            }
        }
        
        guard let lastAlt = lastAltitude else { return 35000.0 }
        
        let verticalRate = flight.verticalRate ?? 0.0
        let predictedAltitude = lastAlt + (verticalRate * timeSinceAltitude)
        
        return max(0, predictedAltitude)
    }
    
    private func estimateFromVelocity(_ velocity: Double) -> Double {
        // Use performance curves for estimation
        if velocity < 50 {      // Ground
            return 0.0
        } else if velocity < 150 {   // Takeoff/climb
            return 5000.0
        } else if velocity < 250 {   // Climb
            return 15000.0
        } else if velocity < 350 {  // Cruise climb
            return 25000.0
        } else if velocity < 450 {  // Cruise
            return 35000.0
        } else {                 // High altitude cruise
            return 40000.0
        }
    }
    
    private func estimateFromFlightPhase(flight: Flight, history: [Flight]) -> Double {
        // Analyze recent trajectory
        let recentPositions = history.suffix(5).compactMap { prevFlight -> CLLocationCoordinate2D? in
            guard prevFlight.id == flight.id,
                  let lat = prevFlight.latitude,
                  let lon = prevFlight.longitude else { return nil }
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
        
        if recentPositions.count < 2 {
            return 35000.0
        }
        
        // Analyze trajectory characteristics
        let altitudeChange = analyzeTrajectory(recentPositions)
        
        if altitudeChange > 0.1 {  // Climbing
            return 20000.0
        } else if altitudeChange < -0.1 {  // Descending
            return 30000.0
        } else {  // Level flight
            return 35000.0
        }
    }
    
    private func analyzeTrajectory(_ positions: [CLLocationCoordinate2D]) -> Double {
        guard positions.count >= 2 else { return 0.0 }
        
        var bearingChanges: [Double] = []
        
        for i in 1..<positions.count {
            let bearing1 = calculateBearing(from: positions[i-1], to: positions[i])
            let bearing2 = calculateBearing(from: positions[i], to: positions[i+1])
            bearingChanges.append(bearing2 - bearing1)
        }
        
        return bearingChanges.reduce(0, +) / Double(bearingChanges.count)
    }
    
    private func calculateBearing(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let lat1 = from.latitude * .pi / 180
        let lat2 = to.latitude * .pi / 180
        let dLon = (to.longitude - from.longitude) * .pi / 180
        
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        
        return atan2(y, x) * 180 / .pi
    }
    
    private func isReasonableAltitude(_ altitude: Double) -> Bool {
        return altitude >= 0 && altitude <= 50000
    }
    
    // MARK: - Legacy Methods (for backward compatibility)
    
    private func estimateAltitudeFromVelocity(velocity: Double?) -> Double {
        guard let velocity = velocity, velocity > 0 else {
            // If no velocity data, assume cruising altitude
            return 35000.0
        }
        
        // Rough estimation based on velocity
        if velocity < 100 {
            return 5000.0  // Takeoff/landing phase
        } else if velocity < 200 {
            return 15000.0 // Climbing phase
        } else if velocity < 300 {
            return 25000.0 // Mid-altitude
        } else {
            return 35000.0 // Cruising phase
        }
    }
    
    func getStandardAltitude(above seaLevel: Bool = true) -> Double {
        // Return a standard cruising altitude
        return above seaLevel ? 35000.0 : 0.0
    }
    
    func isAltitudeReasonable(_ altitude: Double) -> Bool {
        // Check if altitude is within reasonable bounds for commercial aviation
        return altitude >= 0 && altitude <= 50000
    }
}
