import Foundation
import CoreLocation
import simd

class MathHelpers {
    
    // MARK: - Coordinate Conversion
    
    /// Convert geographic coordinates to ARKit world coordinates
    static func geographicToARKit(latitude: Double, longitude: Double, altitude: Double, referenceLocation: CLLocation) -> simd_float3 {
        // Convert to meters from reference point
        let location = CLLocation(latitude: latitude, longitude: longitude)
        let distance = location.distance(from: referenceLocation)
        let bearing = referenceLocation.bearing(to: location)
        
        // Convert to ARKit coordinates (X = East, Y = Up, Z = North)
        let x = Float(distance * sin(bearing * .pi / 180))
        let y = Float(altitude)
        let z = Float(distance * cos(bearing * .pi / 180))
        
        return simd_float3(x, y, z)
    }
    
    /// Calculate bearing between two locations
    static func bearing(from: CLLocation, to: CLLocation) -> Double {
        let lat1 = from.coordinate.latitude * .pi / 180
        let lat2 = to.coordinate.latitude * .pi / 180
        let deltaLon = (to.coordinate.longitude - from.coordinate.longitude) * .pi / 180
        
        let y = sin(deltaLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(deltaLon)
        
        let bearing = atan2(y, x) * 180 / .pi
        return (bearing + 360).truncatingRemainder(dividingBy: 360)
    }
    
    // MARK: - Distance Calculations
    
    /// Calculate distance between two 3D points
    static func distance3D(_ point1: simd_float3, _ point2: simd_float3) -> Float {
        return simd_length(point2 - point1)
    }
    
    /// Calculate 2D distance (ignoring altitude)
    static func distance2D(_ point1: simd_float3, _ point2: simd_float3) -> Float {
        let dx = point2.x - point1.x
        let dz = point2.z - point1.z
        return sqrt(dx * dx + dz * dz)
    }
    
    // MARK: - ARKit Utilities
    
    /// Check if a point is within the camera's field of view
    static func isPointInFOV(_ point: simd_float3, cameraTransform: simd_float4x4, fov: Float = 60.0) -> Bool {
        let cameraPosition = simd_float3(cameraTransform.columns.3.x, cameraTransform.columns.3.y, cameraTransform.columns.3.z)
        let direction = normalize(point - cameraPosition)
        let forward = simd_float3(-cameraTransform.columns.2.x, -cameraTransform.columns.2.y, -cameraTransform.columns.2.z)
        
        let dotProduct = dot(direction, forward)
        let angle = acos(dotProduct) * 180 / .pi
        
        return angle <= fov / 2
    }
    
    /// Calculate scale factor for AR objects based on distance
    static func calculateScale(distance: Float, baseScale: Float = 1.0) -> Float {
        // Scale objects smaller as they get farther away
        let maxDistance: Float = 10000.0 // 10km
        let minScale: Float = 0.1
        let maxScale: Float = 2.0
        
        let normalizedDistance = min(distance / maxDistance, 1.0)
        let scale = baseScale * (maxScale - (maxScale - minScale) * (1.0 - normalizedDistance)
        
        return max(scale, minScale)
    }
    
    // MARK: - Filtering and Smoothing
    
    /// Apply low-pass filter to smooth position updates
    static func smoothPosition(current: simd_float3, previous: simd_float3, alpha: Float = 0.1) -> simd_float3 {
        return current * alpha + previous * (1.0 - alpha)
    }
    
    /// Check if position change is significant enough to update
    static func shouldUpdatePosition(new: simd_float3, old: simd_float3, threshold: Float = 10.0) -> Bool {
        return distance3D(new, old) > threshold
    }
}

// MARK: - CLLocation Extension

extension CLLocation {
    func bearing(to destination: CLLocation) -> Double {
        return MathHelpers.bearing(from: self, to: destination)
    }
}
