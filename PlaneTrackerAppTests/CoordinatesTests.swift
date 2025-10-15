import XCTest
@testable import PlaneTrackerApp
import CoreLocation

class CoordinatesTests: XCTestCase {
    
    // MARK: - Geographic to AR Coordinate Conversion Tests
    
    func testGeographicToARCoordinateConversion() {
        let coordinates = Coordinates(latitude: 37.7749, longitude: -122.4194, altitude: 100.0)
        let arPosition = coordinates.toARWorldCoordinates()
        
        // San Francisco coordinates should convert to reasonable AR positions
        XCTAssertNotNil(arPosition)
        XCTAssertTrue(arPosition.x.isFinite)
        XCTAssertTrue(arPosition.y.isFinite)
        XCTAssertTrue(arPosition.z.isFinite)
    }
    
    func testARCoordinateConversionWithDifferentAltitudes() {
        let baseCoordinates = Coordinates(latitude: 37.7749, longitude: -122.4194, altitude: 0.0)
        let highCoordinates = Coordinates(latitude: 37.7749, longitude: -122.4194, altitude: 1000.0)
        
        let baseAR = baseCoordinates.toARWorldCoordinates()
        let highAR = highCoordinates.toARWorldCoordinates()
        
        // Higher altitude should result in higher Y position in AR
        XCTAssertGreaterThan(highAR.y, baseAR.y)
    }
    
    // MARK: - Distance Calculation Tests
    
    func testDistanceCalculation() {
        let coord1 = Coordinates(latitude: 37.7749, longitude: -122.4194, altitude: 100.0)
        let coord2 = Coordinates(latitude: 37.7849, longitude: -122.4094, altitude: 200.0)
        
        let distance = coord1.distance(to: coord2)
        
        // Distance should be positive and reasonable (roughly 1.4 km for this test case)
        XCTAssertGreaterThan(distance, 0)
        XCTAssertLessThan(distance, 2000) // Less than 2km
    }
    
    func testDistanceCalculationSamePoint() {
        let coord1 = Coordinates(latitude: 37.7749, longitude: -122.4194, altitude: 100.0)
        let coord2 = Coordinates(latitude: 37.7749, longitude: -122.4194, altitude: 100.0)
        
        let distance = coord1.distance(to: coord2)
        
        // Same point should have zero distance
        XCTAssertEqual(distance, 0, accuracy: 0.001)
    }
    
    func testDistanceCalculation3D() {
        let coord1 = Coordinates(latitude: 37.7749, longitude: -122.4194, altitude: 100.0)
        let coord2 = Coordinates(latitude: 37.7749, longitude: -122.4194, altitude: 200.0)
        
        let distance = coord1.distance3D(to: coord2)
        
        // 3D distance should be greater than 2D distance for different altitudes
        let distance2D = coord1.distance(to: coord2)
        XCTAssertGreaterThan(distance, distance2D)
    }
    
    // MARK: - Bearing Calculation Tests
    
    func testBearingCalculation() {
        let coord1 = Coordinates(latitude: 37.7749, longitude: -122.4194, altitude: 100.0)
        let coord2 = Coordinates(latitude: 37.7849, longitude: -122.4094, altitude: 200.0)
        
        let bearing = coord1.bearing(to: coord2)
        
        // Bearing should be between 0 and 360 degrees
        XCTAssertGreaterThanOrEqual(bearing, 0)
        XCTAssertLessThan(bearing, 360)
    }
    
    func testBearingCalculationNorth() {
        let coord1 = Coordinates(latitude: 37.7749, longitude: -122.4194, altitude: 100.0)
        let coord2 = Coordinates(latitude: 37.7849, longitude: -122.4194, altitude: 200.0)
        
        let bearing = coord1.bearing(to: coord2)
        
        // North bearing should be close to 0 degrees
        XCTAssertEqual(bearing, 0, accuracy: 1.0)
    }
    
    func testBearingCalculationEast() {
        let coord1 = Coordinates(latitude: 37.7749, longitude: -122.4194, altitude: 100.0)
        let coord2 = Coordinates(latitude: 37.7749, longitude: -122.4094, altitude: 200.0)
        
        let bearing = coord1.bearing(to: coord2)
        
        // East bearing should be close to 90 degrees
        XCTAssertEqual(bearing, 90, accuracy: 1.0)
    }
    
    func testBearingCalculationSouth() {
        let coord1 = Coordinates(latitude: 37.7849, longitude: -122.4194, altitude: 100.0)
        let coord2 = Coordinates(latitude: 37.7749, longitude: -122.4194, altitude: 200.0)
        
        let bearing = coord1.bearing(to: coord2)
        
        // South bearing should be close to 180 degrees
        XCTAssertEqual(bearing, 180, accuracy: 1.0)
    }
    
    func testBearingCalculationWest() {
        let coord1 = Coordinates(latitude: 37.7749, longitude: -122.4094, altitude: 100.0)
        let coord2 = Coordinates(latitude: 37.7749, longitude: -122.4194, altitude: 200.0)
        
        let bearing = coord1.bearing(to: coord2)
        
        // West bearing should be close to 270 degrees
        XCTAssertEqual(bearing, 270, accuracy: 1.0)
    }
    
    // MARK: - ARKit Utilities Tests
    
    func testARFieldOfView() {
        let fov = Coordinates.arFieldOfView()
        
        // FOV should be reasonable for AR
        XCTAssertGreaterThan(fov, 0)
        XCTAssertLessThan(fov, 180) // Less than 180 degrees
    }
    
    func testARScale() {
        let scale = Coordinates.arScale()
        
        // Scale should be positive
        XCTAssertGreaterThan(scale, 0)
    }
    
    // MARK: - Position Smoothing Tests
    
    func testPositionSmoothing() {
        let coordinates = Coordinates(latitude: 37.7749, longitude: -122.4194, altitude: 100.0)
        let smoothed = coordinates.smoothedPosition()
        
        // Smoothed position should be close to original
        XCTAssertEqual(coordinates.latitude, smoothed.latitude, accuracy: 0.001)
        XCTAssertEqual(coordinates.longitude, smoothed.longitude, accuracy: 0.001)
        XCTAssertEqual(coordinates.altitude, smoothed.altitude, accuracy: 0.001)
    }
    
    func testPositionFiltering() {
        let coordinates = Coordinates(latitude: 37.7749, longitude: -122.4194, altitude: 100.0)
        let filtered = coordinates.filteredPosition()
        
        // Filtered position should be close to original
        XCTAssertEqual(coordinates.latitude, filtered.latitude, accuracy: 0.001)
        XCTAssertEqual(coordinates.longitude, filtered.longitude, accuracy: 0.001)
        XCTAssertEqual(coordinates.altitude, filtered.altitude, accuracy: 0.001)
    }
    
    // MARK: - CLLocation Extension Tests
    
    func testCLLocationExtension() {
        let location = CLLocation(latitude: 37.7749, longitude: -122.4194)
        let coordinates = location.toCoordinates(altitude: 100.0)
        
        XCTAssertEqual(coordinates.latitude, 37.7749, accuracy: 0.0001)
        XCTAssertEqual(coordinates.longitude, -122.4194, accuracy: 0.0001)
        XCTAssertEqual(coordinates.altitude, 100.0, accuracy: 0.001)
    }
    
    // MARK: - Edge Cases Tests
    
    func testZeroCoordinates() {
        let coordinates = Coordinates(latitude: 0.0, longitude: 0.0, altitude: 0.0)
        let arPosition = coordinates.toARWorldCoordinates()
        
        // Should handle zero coordinates without crashing
        XCTAssertNotNil(arPosition)
        XCTAssertTrue(arPosition.x.isFinite)
        XCTAssertTrue(arPosition.y.isFinite)
        XCTAssertTrue(arPosition.z.isFinite)
    }
    
    func testNegativeAltitude() {
        let coordinates = Coordinates(latitude: 37.7749, longitude: -122.4194, altitude: -100.0)
        let arPosition = coordinates.toARWorldCoordinates()
        
        // Should handle negative altitude
        XCTAssertNotNil(arPosition)
        XCTAssertTrue(arPosition.y.isFinite)
    }
    
    func testExtremeCoordinates() {
        let coordinates = Coordinates(latitude: 89.0, longitude: 179.0, altitude: 50000.0)
        let arPosition = coordinates.toARWorldCoordinates()
        
        // Should handle extreme coordinates
        XCTAssertNotNil(arPosition)
        XCTAssertTrue(arPosition.x.isFinite)
        XCTAssertTrue(arPosition.y.isFinite)
        XCTAssertTrue(arPosition.z.isFinite)
    }
}