import Foundation
import CoreLocation

struct Coordinates {
    let latitude: Double
    let longitude: Double
    let altitude: Double
    
    // ARKit world coordinates
    var x: Float
    var y: Float
    var z: Float
    
    init(latitude: Double, longitude: Double, altitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
        self.altitude = altitude
        
        // Convert to ARKit coordinates (simplified conversion)
        // In a real implementation, you'd use proper coordinate transformation
        self.x = Float(longitude * 111000) // Rough conversion to meters
        self.y = Float(altitude)
        self.z = Float(latitude * 111000)
    }
    
    init(from flight: Flight) {
        self.latitude = flight.latitude ?? 0.0
        self.longitude = flight.longitude ?? 0.0
        self.altitude = flight.baroAltitude ?? flight.geoAltitude ?? 0.0
        
        // Convert to ARKit coordinates
        self.x = Float(longitude * 111000)
        self.y = Float(altitude)
        self.z = Float(latitude * 111000)
    }
    
    var clLocation: CLLocation {
        return CLLocation(latitude: latitude, longitude: longitude)
    }
    
    func distance(to other: Coordinates) -> Double {
        return clLocation.distance(from: other.clLocation)
    }
}
