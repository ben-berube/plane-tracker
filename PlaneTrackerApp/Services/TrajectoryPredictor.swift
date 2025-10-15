import Foundation
import CoreLocation
import simd

class TrajectoryPredictor {
    
    private let earthRadius: Double = 6371000  // Earth radius in meters
    private let gravity: Double = 9.81  // Gravity constant
    
    // MARK: - Main Trajectory Prediction
    
    func predictTrajectory(for flight: Flight, 
                          predictionTime: Double = 60.0, 
                          timeStep: Double = 2.0) -> [TrajectoryPoint] {
        
        // First priority: Use backend predicted trajectory
        if let predictedTrajectory = flight.predictedTrajectory, !predictedTrajectory.isEmpty {
            return convertBackendTrajectory(predictedTrajectory)
        }
        
        // Fallback: Use local prediction when backend unavailable
        return predictTrajectoryLocally(for: flight, predictionTime: predictionTime, timeStep: timeStep)
    }
    
    private func convertBackendTrajectory(_ backendTrajectory: [[String: Any]]) -> [TrajectoryPoint] {
        return backendTrajectory.compactMap { pointDict in
            guard let latitude = pointDict["latitude"] as? Double,
                  let longitude = pointDict["longitude"] as? Double,
                  let altitude = pointDict["altitude"] as? Double,
                  let timeOffset = pointDict["time_offset"] as? Double,
                  let distanceFromCurrent = pointDict["distance_from_current"] as? Double,
                  let bearing = pointDict["bearing"] as? Double else {
                return nil
            }
            
            return TrajectoryPoint(
                latitude: latitude,
                longitude: longitude,
                altitude: altitude,
                timeOffset: timeOffset,
                distanceFromCurrent: distanceFromCurrent,
                bearing: bearing
            )
        }
    }
    
    private func predictTrajectoryLocally(for flight: Flight, 
                                        predictionTime: Double = 60.0, 
                                        timeStep: Double = 2.0) -> [TrajectoryPoint] {
        
        guard let lat = flight.latitude,
              let lon = flight.longitude else {
            return []
        }
        
        let alt = flight.baroAltitude ?? flight.geoAltitude ?? 35000
        let velocity = flight.velocity ?? 0
        let track = flight.trueTrack ?? 0
        let verticalRate = flight.verticalRate ?? 0
        
        // Convert to 3D position
        let currentPos = latLonAltTo3D(latitude: lat, longitude: lon, altitude: alt)
        
        // Calculate velocity vector
        let velocityVector = calculateVelocityVector(
            velocity: velocity, 
            track: track, 
            verticalRate: verticalRate
        )
        
        // Predict trajectory
        var trajectory: [TrajectoryPoint] = []
        var time = 0.0
        
        while time <= predictionTime {
            let predictedPos = predictPosition(
                initialPos: currentPos,
                velocityVector: velocityVector,
                time: time,
                altitude: alt,
                speed: velocity
            )
            
            let (predLat, predLon, predAlt) = d3ToLatLonAlt(position: predictedPos)
            
            let trajectoryPoint = TrajectoryPoint(
                latitude: predLat,
                longitude: predLon,
                altitude: predAlt,
                timeOffset: time,
                distanceFromCurrent: calculateDistance(
                    from: (lat, lon, alt),
                    to: (predLat, predLon, predAlt)
                ),
                bearing: calculateBearing(
                    from: (lat, lon),
                    to: (predLat, predLon)
                )
            )
            
            trajectory.append(trajectoryPoint)
            time += timeStep
        }
        
        return trajectory
    }
    
    // MARK: - 3D Coordinate Conversion
    
    private func latLonAltTo3D(latitude: Double, longitude: Double, altitude: Double) -> SIMD3<Double> {
        let latRad = latitude * .pi / 180
        let lonRad = longitude * .pi / 180
        
        let x = (earthRadius + altitude) * cos(latRad) * cos(lonRad)
        let y = (earthRadius + altitude) * cos(latRad) * sin(lonRad)
        let z = (earthRadius + altitude) * sin(latRad)
        
        return SIMD3<Double>(x, y, z)
    }
    
    private func d3ToLatLonAlt(position: SIMD3<Double>) -> (Double, Double, Double) {
        let x = position.x
        let y = position.y
        let z = position.z
        
        let lat = asin(z / length(position)) * 180 / .pi
        let lon = atan2(y, x) * 180 / .pi
        let alt = length(position) - earthRadius
        
        return (lat, lon, alt)
    }
    
    // MARK: - Velocity Vector Calculation
    
    private func calculateVelocityVector(velocity: Double, track: Double, verticalRate: Double) -> SIMD3<Double> {
        let trackRad = track * .pi / 180
        
        let vNorth = velocity * cos(trackRad)  // North component
        let vEast = velocity * sin(trackRad)   // East component
        let vUp = verticalRate                 // Vertical component
        
        return SIMD3<Double>(vNorth, vEast, vUp)
    }
    
    // MARK: - Position Prediction
    
    private func predictPosition(initialPos: SIMD3<Double>, 
                               velocityVector: SIMD3<Double>, 
                               time: Double,
                               altitude: Double,
                               speed: Double) -> SIMD3<Double> {
        
        // Enhanced kinematic prediction with aircraft dynamics
        var predictedPos = initialPos + velocityVector * time
        
        // Apply altitude-based corrections
        let altitudeFactor = getAltitudeCorrectionFactor(altitude: altitude)
        predictedPos = predictedPos * altitudeFactor
        
        // Ensure we stay on Earth's surface
        let distanceFromCenter = length(predictedPos)
        if distanceFromCenter < earthRadius {
            // Project back to Earth's surface
            predictedPos = predictedPos * (earthRadius / distanceFromCenter)
        }
        
        return predictedPos
    }
    
    private func getAltitudeCorrectionFactor(altitude: Double) -> Double {
        if altitude < 1000 {
            return 1.0      // Ground level
        } else if altitude < 5000 {
            return 1.001    // Low altitude
        } else if altitude < 15000 {
            return 1.002    // Medium altitude
        } else if altitude < 30000 {
            return 1.003    // High altitude
        } else {
            return 1.004    // Very high altitude
        }
    }
    
    // MARK: - Distance and Bearing Calculations
    
    private func calculateDistance(from: (Double, Double, Double), to: (Double, Double, Double)) -> Double {
        let (lat1, lon1, alt1) = from
        let (lat2, lon2, alt2) = to
        
        // Haversine formula for horizontal distance
        let lat1Rad = lat1 * .pi / 180
        let lat2Rad = lat2 * .pi / 180
        let dLat = (lat2 - lat1) * .pi / 180
        let dLon = (lon2 - lon1) * .pi / 180
        
        let a = sin(dLat/2) * sin(dLat/2) + cos(lat1Rad) * cos(lat2Rad) * sin(dLon/2) * sin(dLon/2)
        let c = 2 * asin(sqrt(a))
        
        let horizontalDistance = earthRadius * c
        
        // Vertical distance
        let verticalDistance = abs(alt2 - alt1)
        
        // 3D distance
        return sqrt(horizontalDistance * horizontalDistance + verticalDistance * verticalDistance)
    }
    
    private func calculateBearing(from: (Double, Double), to: (Double, Double)) -> Double {
        let (lat1, lon1) = from
        let (lat2, lon2) = to
        
        let lat1Rad = lat1 * .pi / 180
        let lat2Rad = lat2 * .pi / 180
        let dLonRad = (lon2 - lon1) * .pi / 180
        
        let y = sin(dLonRad) * cos(lat2Rad)
        let x = cos(lat1Rad) * sin(lat2Rad) - sin(lat1Rad) * cos(lat2Rad) * cos(dLonRad)
        
        let bearing = atan2(y, x)
        return bearing * 180 / .pi
    }
    
    // MARK: - AR Camera Integration
    
    func calculateTrajectoryForAR(flight: Flight,
                                cameraPosition: SIMD3<Float>,
                                cameraOrientation: SIMD3<Float>,
                                fieldOfView: Float = 60.0) -> [TrajectoryPoint] {
        
        // Get predicted trajectory
        let trajectory = predictTrajectory(for: flight)
        
        // Filter points within camera view
        let visiblePoints = trajectory.filter { point in
            let point3D = latLonAltTo3D(
                latitude: point.latitude,
                longitude: point.longitude,
                altitude: point.altitude
            )
            
            return isPointInCameraView(
                point3D: point3D,
                cameraPosition: cameraPosition,
                cameraOrientation: cameraOrientation,
                fieldOfView: fieldOfView
            )
        }
        
        return visiblePoints
    }
    
    private func isPointInCameraView(point3D: SIMD3<Double>,
                                   cameraPosition: SIMD3<Float>,
                                   cameraOrientation: SIMD3<Float>,
                                   fieldOfView: Float) -> Bool {
        
        // Convert to Float for calculations
        let point3DFloat = SIMD3<Float>(Float(point3D.x), Float(point3D.y), Float(point3D.z))
        
        // Calculate vector from camera to point
        let cameraToPoint = point3DFloat - cameraPosition
        
        // Calculate angle between camera direction and point
        let angle = acos(dot(normalize(cameraToPoint), normalize(cameraOrientation)))
        
        // Check if within field of view
        return angle <= (fieldOfView * .pi / 180) / 2
    }
    
    // MARK: - Utility Functions
    
    func getTrajectoryStatistics(trajectory: [TrajectoryPoint]) -> TrajectoryStatistics {
        guard !trajectory.isEmpty else {
            return TrajectoryStatistics(
                totalDistance: 0,
                averageSpeed: 0,
                maxAltitude: 0,
                minAltitude: 0,
                altitudeRange: 0,
                bearingChange: 0
            )
        }
        
        let totalDistance = trajectory.last?.distanceFromCurrent ?? 0
        let averageSpeed = totalDistance / (trajectory.last?.timeOffset ?? 1)
        
        let altitudes = trajectory.map { $0.altitude }
        let maxAltitude = altitudes.max() ?? 0
        let minAltitude = altitudes.min() ?? 0
        let altitudeRange = maxAltitude - minAltitude
        
        // Calculate bearing change
        var bearingChanges: [Double] = []
        for i in 1..<trajectory.count {
            let bearingChange = trajectory[i].bearing - trajectory[i-1].bearing
            bearingChanges.append(bearingChange)
        }
        let avgBearingChange = bearingChanges.reduce(0, +) / Double(bearingChanges.count)
        
        return TrajectoryStatistics(
            totalDistance: totalDistance,
            averageSpeed: averageSpeed,
            maxAltitude: maxAltitude,
            minAltitude: minAltitude,
            altitudeRange: altitudeRange,
            bearingChange: avgBearingChange
        )
    }
}

// MARK: - Data Structures

struct TrajectoryPoint {
    let latitude: Double
    let longitude: Double
    let altitude: Double
    let timeOffset: Double
    let distanceFromCurrent: Double
    let bearing: Double
}

struct TrajectoryStatistics {
    let totalDistance: Double
    let averageSpeed: Double
    let maxAltitude: Double
    let minAltitude: Double
    let altitudeRange: Double
    let bearingChange: Double
}
