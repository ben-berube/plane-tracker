import Foundation

class AltitudeFallback {
    
    // Standard altitude levels for different flight phases
    private let standardAltitudes: [Int] = [1000, 2000, 3000, 4000, 5000, 6000, 7000, 8000, 9000, 10000, 11000, 12000, 13000, 14000, 15000, 16000, 17000, 18000, 19000, 20000, 21000, 22000, 23000, 24000, 25000, 26000, 27000, 28000, 29000, 30000, 31000, 32000, 33000, 34000, 35000, 36000, 37000, 38000, 39000, 40000, 41000, 42000, 43000, 44000, 45000, 46000, 47000, 48000, 49000, 50000]
    
    func estimateAltitude(for flight: Flight) -> Double {
        // If we have barometric altitude, use it
        if let baroAltitude = flight.baroAltitude, baroAltitude > 0 {
            return baroAltitude
        }
        
        // If we have geometric altitude, use it
        if let geoAltitude = flight.geoAltitude, geoAltitude > 0 {
            return geoAltitude
        }
        
        // If on ground, return 0
        if flight.onGround {
            return 0.0
        }
        
        // Estimate based on velocity and flight phase
        return estimateAltitudeFromVelocity(velocity: flight.velocity)
    }
    
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
