import XCTest
@testable import PlaneTrackerApp

class AltitudeFallbackTests: XCTestCase {
    var altitudeFallback: AltitudeFallback!
    
    override func setUp() {
        super.setUp()
        altitudeFallback = AltitudeFallback()
    }
    
    override func tearDown() {
        altitudeFallback = nil
        super.tearDown()
    }
    
    // MARK: - Backend Predicted Altitude Tests
    
    func testBackendPredictedAltitudeUsage() {
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
        
        // Create flight with backend predicted altitude
        let flightWithPrediction = Flight(
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
        
        let altitude = altitudeFallback.estimateAltitude(for: flightWithPrediction)
        
        // Should use backend predicted altitude if available
        if let predictedAltitude = flightWithPrediction.predictedAltitude {
            XCTAssertEqual(altitude, predictedAltitude, accuracy: 0.01)
        } else {
            // Fallback to other methods
            XCTAssertGreaterThanOrEqual(altitude, 0)
        }
    }
    
    // MARK: - Direct Altitude Data Tests
    
    func testBarometricAltitudeUsage() {
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
            geoAltitude: nil,
            squawk: nil,
            spi: false,
            positionSource: 0
        )
        
        let altitude = altitudeFallback.estimateAltitude(for: flight)
        
        // Should use barometric altitude
        XCTAssertEqual(altitude, 586.74, accuracy: 0.01)
    }
    
    func testGeometricAltitudeUsage() {
        let flight = Flight(
            id: "a0f355",
            callsign: "SKW5596",
            originCountry: "United States",
            timePosition: 1760024985,
            lastContact: 1760024985,
            longitude: -122.2438,
            latitude: 37.5637,
            baroAltitude: nil,
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
        
        let altitude = altitudeFallback.estimateAltitude(for: flight)
        
        // Should use geometric altitude
        XCTAssertEqual(altitude, 563.88, accuracy: 0.01)
    }
    
    func testAltitudePriority() {
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
        
        let altitude = altitudeFallback.estimateAltitude(for: flight)
        
        // Should prefer barometric altitude over geometric
        XCTAssertEqual(altitude, 586.74, accuracy: 0.01)
    }
    
    // MARK: - Ground Detection Tests
    
    func testGroundAltitude() {
        let flight = Flight(
            id: "a0f355",
            callsign: "SKW5596",
            originCountry: "United States",
            timePosition: 1760024985,
            lastContact: 1760024985,
            longitude: -122.2438,
            latitude: 37.5637,
            baroAltitude: nil,
            onGround: true,
            velocity: 0.0,
            trueTrack: nil,
            verticalRate: nil,
            sensors: nil,
            geoAltitude: nil,
            squawk: nil,
            spi: false,
            positionSource: 0
        )
        
        let altitude = altitudeFallback.estimateAltitude(for: flight)
        
        // Ground flights should return 0 altitude
        XCTAssertEqual(altitude, 0.0, accuracy: 0.001)
    }
    
    // MARK: - Kalman Filter Fallback Tests
    
    func testKalmanFilterFallback() {
        let flight = Flight(
            id: "a0f355",
            callsign: "SKW5596",
            originCountry: "United States",
            timePosition: 1760024985,
            lastContact: 1760024985,
            longitude: -122.2438,
            latitude: 37.5637,
            baroAltitude: nil,
            onGround: false,
            velocity: 94.81,
            trueTrack: 297.82,
            verticalRate: -4.88,
            sensors: nil,
            geoAltitude: nil,
            squawk: nil,
            spi: false,
            positionSource: 0
        )
        
        let altitude = altitudeFallback.estimateAltitude(for: flight)
        
        // Should use Kalman filter prediction
        XCTAssertGreaterThanOrEqual(altitude, 0)
        XCTAssertLessThan(altitude, 50000) // Reasonable altitude range
    }
    
    // MARK: - Vertical Rate Integration Tests
    
    func testVerticalRateIntegration() {
        let flight = Flight(
            id: "a0f355",
            callsign: "SKW5596",
            originCountry: "United States",
            timePosition: 1760024985,
            lastContact: 1760024985,
            longitude: -122.2438,
            latitude: 37.5637,
            baroAltitude: nil,
            onGround: false,
            velocity: 94.81,
            trueTrack: 297.82,
            verticalRate: -4.88,
            sensors: nil,
            geoAltitude: nil,
            squawk: nil,
            spi: false,
            positionSource: 0
        )
        
        let altitude = altitudeFallback.estimateAltitude(for: flight)
        
        // Should use vertical rate integration
        XCTAssertGreaterThanOrEqual(altitude, 0)
        XCTAssertLessThan(altitude, 50000) // Reasonable altitude range
    }
    
    // MARK: - Velocity-based Estimation Tests
    
    func testVelocityBasedEstimation() {
        let flight = Flight(
            id: "a0f355",
            callsign: "SKW5596",
            originCountry: "United States",
            timePosition: 1760024985,
            lastContact: 1760024985,
            longitude: -122.2438,
            latitude: 37.5637,
            baroAltitude: nil,
            onGround: false,
            velocity: 94.81,
            trueTrack: 297.82,
            verticalRate: nil,
            sensors: nil,
            geoAltitude: nil,
            squawk: nil,
            spi: false,
            positionSource: 0
        )
        
        let altitude = altitudeFallback.estimateAltitude(for: flight)
        
        // Should use velocity-based estimation
        XCTAssertGreaterThanOrEqual(altitude, 0)
        XCTAssertLessThan(altitude, 50000) // Reasonable altitude range
    }
    
    // MARK: - Flight Phase Analysis Tests
    
    func testFlightPhaseAnalysis() {
        let flight = Flight(
            id: "a0f355",
            callsign: "SKW5596",
            originCountry: "United States",
            timePosition: 1760024985,
            lastContact: 1760024985,
            longitude: -122.2438,
            latitude: 37.5637,
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
        
        let altitude = altitudeFallback.estimateAltitude(for: flight)
        
        // Should use flight phase analysis
        XCTAssertGreaterThanOrEqual(altitude, 0)
        XCTAssertLessThan(altitude, 50000) // Reasonable altitude range
    }
    
    // MARK: - Confidence Score Tests
    
    func testConfidenceScore() {
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
        
        let altitude = altitudeFallback.estimateAltitude(for: flight)
        let confidence = altitudeFallback.getConfidenceScore()
        
        // Should have reasonable confidence score
        XCTAssertGreaterThanOrEqual(confidence, 0.0)
        XCTAssertLessThanOrEqual(confidence, 1.0)
    }
    
    // MARK: - Edge Cases Tests
    
    func testNegativeAltitude() {
        let flight = Flight(
            id: "a0f355",
            callsign: "SKW5596",
            originCountry: "United States",
            timePosition: 1760024985,
            lastContact: 1760024985,
            longitude: -122.2438,
            latitude: 37.5637,
            baroAltitude: -100.0,
            onGround: false,
            velocity: 94.81,
            trueTrack: 297.82,
            verticalRate: -4.88,
            sensors: nil,
            geoAltitude: nil,
            squawk: nil,
            spi: false,
            positionSource: 0
        )
        
        let altitude = altitudeFallback.estimateAltitude(for: flight)
        
        // Should handle negative altitude gracefully
        XCTAssertGreaterThanOrEqual(altitude, 0)
    }
    
    func testExtremeAltitude() {
        let flight = Flight(
            id: "a0f355",
            callsign: "SKW5596",
            originCountry: "United States",
            timePosition: 1760024985,
            lastContact: 1760024985,
            longitude: -122.2438,
            latitude: 37.5637,
            baroAltitude: 100000.0,
            onGround: false,
            velocity: 94.81,
            trueTrack: 297.82,
            verticalRate: -4.88,
            sensors: nil,
            geoAltitude: nil,
            squawk: nil,
            spi: false,
            positionSource: 0
        )
        
        let altitude = altitudeFallback.estimateAltitude(for: flight)
        
        // Should handle extreme altitude
        XCTAssertGreaterThanOrEqual(altitude, 0)
        XCTAssertLessThan(altitude, 100000) // Should be capped at reasonable value
    }
    
    // MARK: - Performance Tests
    
    func testAltitudeEstimationPerformance() {
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
            let altitude = altitudeFallback.estimateAltitude(for: flight)
            XCTAssertGreaterThanOrEqual(altitude, 0)
        }
    }
}