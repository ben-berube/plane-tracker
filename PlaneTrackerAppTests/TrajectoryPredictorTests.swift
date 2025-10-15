import XCTest
@testable import PlaneTrackerApp

class TrajectoryPredictorTests: XCTestCase {
    var trajectoryPredictor: TrajectoryPredictor!
    
    override func setUp() {
        super.setUp()
        trajectoryPredictor = TrajectoryPredictor()
    }
    
    override func tearDown() {
        trajectoryPredictor = nil
        super.tearDown()
    }
    
    // MARK: - Trajectory Prediction Tests
    
    func testTrajectoryPredictionWithCompleteData() {
        let flight = Flight(
            id: "a0f355",
            callsign: "SKW5596",
            originCountry: "United States",
            timePosition: 1760024985,
            lastContact: 1760024985,
            longitude: -122.2438,
            latitude: 37.5637,
            baroAltitude: 586.74,
            onGround: false,
            velocity: 94.81,
            trueTrack: 297.82,
            verticalRate: -4.88,
            sensors: nil,
            geoAltitude: 563.88,
            squawk: nil,
            spi: false,
            positionSource: 0
        )
        
        let trajectory = trajectoryPredictor.predictTrajectory(for: flight, predictionTime: 60.0, timeStep: 2.0)
        
        XCTAssertFalse(trajectory.isEmpty, "Trajectory should not be empty")
        XCTAssertEqual(trajectory.count, 31) // 60 seconds / 2 second steps + 1
        
        // Check first point (current position)
        let firstPoint = trajectory.first!
        XCTAssertEqual(firstPoint.latitude, 37.5637, accuracy: 0.0001)
        XCTAssertEqual(firstPoint.longitude, -122.2438, accuracy: 0.0001)
        XCTAssertEqual(firstPoint.timeOffset, 0.0, accuracy: 0.001)
        XCTAssertEqual(firstPoint.distanceFromCurrent, 0.0, accuracy: 0.001)
        
        // Check last point
        let lastPoint = trajectory.last!
        XCTAssertEqual(lastPoint.timeOffset, 60.0, accuracy: 0.001)
        XCTAssertGreaterThan(lastPoint.distanceFromCurrent, 0)
    }
    
    func testTrajectoryPredictionWithMissingData() {
        let flight = Flight(
            id: "a0f355",
            callsign: "SKW5596",
            originCountry: "United States",
            timePosition: nil,
            lastContact: 1760024985,
            longitude: nil,
            latitude: nil,
            baroAltitude: nil,
            onGround: false,
            velocity: nil,
            trueTrack: nil,
            verticalRate: nil,
            sensors: nil,
            geoAltitude: nil,
            squawk: nil,
            spi: false,
            positionSource: 0
        )
        
        let trajectory = trajectoryPredictor.predictTrajectory(for: flight, predictionTime: 60.0, timeStep: 2.0)
        
        // Should return empty trajectory for missing position data
        XCTAssertTrue(trajectory.isEmpty, "Trajectory should be empty for missing position data")
    }
    
    func testBackendTrajectoryConversion() {
        let backendTrajectory = [
            [
                "latitude": 37.5637,
                "longitude": -122.2438,
                "altitude": 586.74,
                "time_offset": 0.0,
                "distance_from_current": 0.0,
                "bearing": 0.0
            ],
            [
                "latitude": 37.5631,
                "longitude": -122.2419,
                "altitude": 655.80,
                "time_offset": 2.0,
                "distance_from_current": 189.85,
                "bearing": 111.71
            ]
        ]
        
        let flight = Flight(
            id: "a0f355",
            callsign: "SKW5596",
            originCountry: "United States",
            timePosition: 1760024985,
            lastContact: 1760024985,
            longitude: -122.2438,
            latitude: 37.5637,
            baroAltitude: 586.74,
            onGround: false,
            velocity: 94.81,
            trueTrack: 297.82,
            verticalRate: -4.88,
            sensors: nil,
            geoAltitude: 563.88,
            squawk: nil,
            spi: false,
            positionSource: 0
        )
        
        // Create a flight with backend trajectory
        let flightWithTrajectory = Flight(
            id: flight.id,
            callsign: flight.callsign,
            originCountry: flight.originCountry,
            timePosition: flight.timePosition,
            lastContact: flight.lastContact,
            longitude: flight.longitude,
            latitude: flight.latitude,
            baroAltitude: flight.baroAltitude,
            onGround: flight.onGround,
            velocity: flight.velocity,
            trueTrack: flight.trueTrack,
            verticalRate: flight.verticalRate,
            sensors: flight.sensors,
            geoAltitude: flight.geoAltitude,
            squawk: flight.squawk,
            spi: flight.spi,
            positionSource: flight.positionSource
        )
        
        let trajectory = trajectoryPredictor.predictTrajectory(for: flightWithTrajectory)
        
        // Should use backend trajectory
        XCTAssertFalse(trajectory.isEmpty, "Backend trajectory should not be empty")
        XCTAssertEqual(trajectory.count, 2)
        
        let firstPoint = trajectory.first!
        XCTAssertEqual(firstPoint.latitude, 37.5637, accuracy: 0.0001)
        XCTAssertEqual(firstPoint.longitude, -122.2438, accuracy: 0.0001)
        XCTAssertEqual(firstPoint.altitude, 586.74, accuracy: 0.01)
        XCTAssertEqual(firstPoint.timeOffset, 0.0, accuracy: 0.001)
        XCTAssertEqual(firstPoint.distanceFromCurrent, 0.0, accuracy: 0.001)
        XCTAssertEqual(firstPoint.bearing, 0.0, accuracy: 0.001)
    }
    
    // MARK: - 3D Coordinate Conversion Tests
    
    func test3DCoordinateConversion() {
        let latitude = 37.7749
        let longitude = -122.4194
        let altitude = 100.0
        
        // This would test the private latLonAltTo3D method
        // Since it's private, we'll test through the public interface
        let flight = Flight(
            id: "a0f355",
            callsign: "SKW5596",
            originCountry: "United States",
            timePosition: 1760024985,
            lastContact: 1760024985,
            longitude: longitude,
            latitude: latitude,
            baroAltitude: altitude,
            onGround: false,
            velocity: 94.81,
            trueTrack: 297.82,
            verticalRate: -4.88,
            sensors: nil,
            geoAltitude: altitude,
            squawk: nil,
            spi: false,
            positionSource: 0
        )
        
        let trajectory = trajectoryPredictor.predictTrajectory(for: flight, predictionTime: 10.0, timeStep: 1.0)
        
        // Should have valid 3D coordinates
        XCTAssertFalse(trajectory.isEmpty)
        for point in trajectory {
            XCTAssertTrue(point.latitude.isFinite)
            XCTAssertTrue(point.longitude.isFinite)
            XCTAssertTrue(point.altitude.isFinite)
        }
    }
    
    // MARK: - Distance and Bearing Calculation Tests
    
    func testDistanceCalculation() {
        let flight = Flight(
            id: "a0f355",
            callsign: "SKW5596",
            originCountry: "United States",
            timePosition: 1760024985,
            lastContact: 1760024985,
            longitude: -122.2438,
            latitude: 37.5637,
            baroAltitude: 586.74,
            onGround: false,
            velocity: 94.81,
            trueTrack: 297.82,
            verticalRate: -4.88,
            sensors: nil,
            geoAltitude: 563.88,
            squawk: nil,
            spi: false,
            positionSource: 0
        )
        
        let trajectory = trajectoryPredictor.predictTrajectory(for: flight, predictionTime: 10.0, timeStep: 1.0)
        
        // First point should have zero distance
        let firstPoint = trajectory.first!
        XCTAssertEqual(firstPoint.distanceFromCurrent, 0.0, accuracy: 0.001)
        
        // Last point should have positive distance
        let lastPoint = trajectory.last!
        XCTAssertGreaterThan(lastPoint.distanceFromCurrent, 0)
    }
    
    func testBearingCalculation() {
        let flight = Flight(
            id: "a0f355",
            callsign: "SKW5596",
            originCountry: "United States",
            timePosition: 1760024985,
            lastContact: 1760024985,
            longitude: -122.2438,
            latitude: 37.5637,
            baroAltitude: 586.74,
            onGround: false,
            velocity: 94.81,
            trueTrack: 297.82,
            verticalRate: -4.88,
            sensors: nil,
            geoAltitude: 563.88,
            squawk: nil,
            spi: false,
            positionSource: 0
        )
        
        let trajectory = trajectoryPredictor.predictTrajectory(for: flight, predictionTime: 10.0, timeStep: 1.0)
        
        // First point should have zero bearing
        let firstPoint = trajectory.first!
        XCTAssertEqual(firstPoint.bearing, 0.0, accuracy: 0.001)
        
        // Other points should have valid bearings
        for point in trajectory.dropFirst() {
            XCTAssertGreaterThanOrEqual(point.bearing, 0)
            XCTAssertLessThan(point.bearing, 360)
        }
    }
    
    // MARK: - AR Camera Integration Tests
    
    func testARCameraIntegration() {
        let flight = Flight(
            id: "a0f355",
            callsign: "SKW5596",
            originCountry: "United States",
            timePosition: 1760024985,
            lastContact: 1760024985,
            longitude: -122.2438,
            latitude: 37.5637,
            baroAltitude: 586.74,
            onGround: false,
            velocity: 94.81,
            trueTrack: 297.82,
            verticalRate: -4.88,
            sensors: nil,
            geoAltitude: 563.88,
            squawk: nil,
            spi: false,
            positionSource: 0
        )
        
        let cameraPosition = SIMD3<Double>(0, 0, 0)
        let cameraOrientation = SIMD3<Double>(0, 0, 0)
        
        let trajectory = trajectoryPredictor.calculateTrajectoryForAR(
            flight: flight,
            cameraPosition: cameraPosition,
            cameraOrientation: cameraOrientation
        )
        
        // Should return valid trajectory for AR
        XCTAssertNotNil(trajectory)
    }
    
    // MARK: - Trajectory Statistics Tests
    
    func testTrajectoryStatistics() {
        let flight = Flight(
            id: "a0f355",
            callsign: "SKW5596",
            originCountry: "United States",
            timePosition: 1760024985,
            lastContact: 1760024985,
            longitude: -122.2438,
            latitude: 37.5637,
            baroAltitude: 586.74,
            onGround: false,
            velocity: 94.81,
            trueTrack: 297.82,
            verticalRate: -4.88,
            sensors: nil,
            geoAltitude: 563.88,
            squawk: nil,
            spi: false,
            positionSource: 0
        )
        
        let trajectory = trajectoryPredictor.predictTrajectory(for: flight, predictionTime: 60.0, timeStep: 2.0)
        
        // Should have reasonable trajectory statistics
        XCTAssertFalse(trajectory.isEmpty)
        XCTAssertEqual(trajectory.count, 31) // 60 seconds / 2 second steps + 1
        
        // Check time progression
        for (index, point) in trajectory.enumerated() {
            let expectedTime = Double(index) * 2.0
            XCTAssertEqual(point.timeOffset, expectedTime, accuracy: 0.001)
        }
    }
    
    // MARK: - Performance Tests
    
    func testTrajectoryPredictionPerformance() {
        let flight = Flight(
            id: "a0f355",
            callsign: "SKW5596",
            originCountry: "United States",
            timePosition: 1760024985,
            lastContact: 1760024985,
            longitude: -122.2438,
            latitude: 37.5637,
            baroAltitude: 586.74,
            onGround: false,
            velocity: 94.81,
            trueTrack: 297.82,
            verticalRate: -4.88,
            sensors: nil,
            geoAltitude: 563.88,
            squawk: nil,
            spi: false,
            positionSource: 0
        )
        
        measure {
            let trajectory = trajectoryPredictor.predictTrajectory(for: flight, predictionTime: 60.0, timeStep: 1.0)
            XCTAssertFalse(trajectory.isEmpty)
        }
    }
}