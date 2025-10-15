import XCTest
@testable import PlaneTrackerApp

class FlightModelTests: XCTestCase {
    
    // MARK: - JSON Decoding Tests
    
    func testBackendJSONDecoding() {
        let jsonData = """
        {
            "icao24": "a0f355",
            "callsign": "SKW5596",
            "origin_country": "United States",
            "time_position": 1760024985,
            "last_contact": 1760024985,
            "longitude": -122.2438,
            "latitude": 37.5637,
            "baro_altitude": 586.74,
            "on_ground": false,
            "velocity": 94.81,
            "true_track": 297.82,
            "vertical_rate": -4.88,
            "sensors": null,
            "geo_altitude": 563.88,
            "squawk": null,
            "spi": false,
            "position_source": 0,
            "predicted_altitude": 586.74,
            "altitude_confidence": 0.947956517146085,
            "has_predicted_altitude": false,
            "predicted_trajectory": []
        }
        """.data(using: .utf8)!
        
        do {
            let flight = try JSONDecoder().decode(Flight.self, from: jsonData)
            
            XCTAssertEqual(flight.id, "a0f355")
            XCTAssertEqual(flight.callsign, "SKW5596")
            XCTAssertEqual(flight.originCountry, "United States")
            XCTAssertEqual(flight.longitude, -122.2438, accuracy: 0.0001)
            XCTAssertEqual(flight.latitude, 37.5637, accuracy: 0.0001)
            XCTAssertEqual(flight.baroAltitude, 586.74, accuracy: 0.01)
            XCTAssertFalse(flight.onGround)
            XCTAssertEqual(flight.velocity, 94.81, accuracy: 0.01)
            XCTAssertEqual(flight.trueTrack, 297.82, accuracy: 0.01)
            XCTAssertEqual(flight.verticalRate, -4.88, accuracy: 0.01)
            XCTAssertEqual(flight.geoAltitude, 563.88, accuracy: 0.01)
            XCTAssertFalse(flight.spi)
            XCTAssertEqual(flight.positionSource, 0)
            
            // Backend enhanced fields
            XCTAssertEqual(flight.predictedAltitude, 586.74, accuracy: 0.01)
            XCTAssertEqual(flight.altitudeConfidence, 0.947956517146085, accuracy: 0.0001)
            XCTAssertFalse(flight.hasPredictedAltitude)
            XCTAssertNotNil(flight.predictedTrajectory)
        } catch {
            XCTFail("Failed to decode Flight: \(error)")
        }
    }
    
    func testNilOptionalFields() {
        let jsonData = """
        {
            "icao24": "a0f355",
            "callsign": "SKW5596",
            "origin_country": "United States",
            "time_position": null,
            "last_contact": 1760024985,
            "longitude": null,
            "latitude": null,
            "baro_altitude": null,
            "on_ground": false,
            "velocity": null,
            "true_track": null,
            "vertical_rate": null,
            "sensors": null,
            "geo_altitude": null,
            "squawk": null,
            "spi": false,
            "position_source": 0,
            "predicted_altitude": null,
            "altitude_confidence": null,
            "has_predicted_altitude": false,
            "predicted_trajectory": null
        }
        """.data(using: .utf8)!
        
        do {
            let flight = try JSONDecoder().decode(Flight.self, from: jsonData)
            
            XCTAssertEqual(flight.id, "a0f355")
            XCTAssertEqual(flight.callsign, "SKW5596")
            XCTAssertNil(flight.timePosition)
            XCTAssertNil(flight.longitude)
            XCTAssertNil(flight.latitude)
            XCTAssertNil(flight.baroAltitude)
            XCTAssertNil(flight.velocity)
            XCTAssertNil(flight.trueTrack)
            XCTAssertNil(flight.verticalRate)
            XCTAssertNil(flight.sensors)
            XCTAssertNil(flight.geoAltitude)
            XCTAssertNil(flight.squawk)
            XCTAssertNil(flight.predictedAltitude)
            XCTAssertNil(flight.altitudeConfidence)
            XCTAssertFalse(flight.hasPredictedAltitude)
            XCTAssertNil(flight.predictedTrajectory)
        } catch {
            XCTFail("Failed to decode Flight with nil fields: \(error)")
        }
    }
    
    // MARK: - Coordinate Extraction Tests
    
    func testCoordinateExtraction() {
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
        
        XCTAssertEqual(flight.longitude, -122.2438, accuracy: 0.0001)
        XCTAssertEqual(flight.latitude, 37.5637, accuracy: 0.0001)
    }
    
    // MARK: - Backward Compatibility Tests
    
    func testBackwardCompatibilityInitializer() {
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
        
        // Backend fields should be nil/false for backward compatibility
        XCTAssertNil(flight.predictedAltitude)
        XCTAssertNil(flight.altitudeConfidence)
        XCTAssertFalse(flight.hasPredictedAltitude)
        XCTAssertNil(flight.predictedTrajectory)
    }
    
    // MARK: - Identifiable Protocol Tests
    
    func testIdentifiableProtocol() {
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
        
        XCTAssertEqual(flight.id, "a0f355")
    }
    
    // MARK: - Codable Protocol Tests
    
    func testCodableProtocol() {
        let originalFlight = Flight(
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
        
        do {
            let encoded = try JSONEncoder().encode(originalFlight)
            let decoded = try JSONDecoder().decode(Flight.self, from: encoded)
            
            XCTAssertEqual(originalFlight.id, decoded.id)
            XCTAssertEqual(originalFlight.callsign, decoded.callsign)
            XCTAssertEqual(originalFlight.originCountry, decoded.originCountry)
            XCTAssertEqual(originalFlight.longitude, decoded.longitude)
            XCTAssertEqual(originalFlight.latitude, decoded.latitude)
            XCTAssertEqual(originalFlight.baroAltitude, decoded.baroAltitude)
            XCTAssertEqual(originalFlight.onGround, decoded.onGround)
            XCTAssertEqual(originalFlight.velocity, decoded.velocity)
            XCTAssertEqual(originalFlight.trueTrack, decoded.trueTrack)
            XCTAssertEqual(originalFlight.verticalRate, decoded.verticalRate)
            XCTAssertEqual(originalFlight.geoAltitude, decoded.geoAltitude)
            XCTAssertEqual(originalFlight.spi, decoded.spi)
            XCTAssertEqual(originalFlight.positionSource, decoded.positionSource)
        } catch {
            XCTFail("Failed to encode/decode Flight: \(error)")
        }
    }
}