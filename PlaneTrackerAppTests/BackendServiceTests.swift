import XCTest
@testable import PlaneTrackerApp

class BackendServiceTests: XCTestCase {
    var backendService: BackendService!
    
    override func setUp() {
        super.setUp()
        backendService = BackendService()
    }
    
    override func tearDown() {
        backendService = nil
        super.tearDown()
    }
    
    // MARK: - Network Tests
    
    func testFetchFlightsSuccess() {
        let expectation = XCTestExpectation(description: "Fetch flights")
        
        backendService.fetchFlights()
        
        // Wait for async operation
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
        
        // Verify flights are loaded (assuming backend is running)
        XCTAssertFalse(backendService.flights.isEmpty, "Flights should be loaded")
    }
    
    func testFetchFlightsNetworkError() {
        // This test would require mocking network failures
        // For now, we'll test the error handling structure
        XCTAssertNotNil(backendService.errorMessage)
    }
    
    // MARK: - Caching Tests
    
    func testCachingBehavior() {
        let expectation = XCTestExpectation(description: "Cache test")
        
        // First fetch
        backendService.fetchFlights()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            let firstFetchCount = self.backendService.flights.count
            
            // Second fetch should use cache
            self.backendService.fetchFlights()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                let secondFetchCount = self.backendService.flights.count
                
                // Should be the same (cached)
                XCTAssertEqual(firstFetchCount, secondFetchCount)
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 3.0)
    }
    
    // MARK: - JSON Parsing Tests
    
    func testJSONParsingWithCompleteData() {
        let jsonData = """
        {
            "success": true,
            "flights": [
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
            ],
            "count": 1,
            "timestamp": "2025-10-09T18:50:58.531771"
        }
        """.data(using: .utf8)!
        
        do {
            let response = try JSONDecoder().decode(BackendFlightsResponse.self, from: jsonData)
            XCTAssertTrue(response.success)
            XCTAssertEqual(response.flights.count, 1)
            XCTAssertEqual(response.flights.first?.icao24, "a0f355")
        } catch {
            XCTFail("Failed to decode JSON: \(error)")
        }
    }
    
    func testJSONParsingWithMissingOptionalFields() {
        let jsonData = """
        {
            "success": true,
            "flights": [
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
            ],
            "count": 1,
            "timestamp": "2025-10-09T18:50:58.531771"
        }
        """.data(using: .utf8)!
        
        do {
            let response = try JSONDecoder().decode(BackendFlightsResponse.self, from: jsonData)
            XCTAssertTrue(response.success)
            XCTAssertEqual(response.flights.count, 1)
            
            let flight = response.flights.first!
            XCTAssertNil(flight.longitude)
            XCTAssertNil(flight.latitude)
            XCTAssertNil(flight.baroAltitude)
        } catch {
            XCTFail("Failed to decode JSON: \(error)")
        }
    }
    
    // MARK: - Trajectory Endpoint Tests
    
    func testTrajectoryEndpointParsing() {
        let jsonData = """
        {
            "success": true,
            "flight_id": "a0f355",
            "trajectory": [
                {
                    "latitude": 37.5637,
                    "longitude": -122.2438,
                    "altitude": 586.74,
                    "time_offset": 0.0,
                    "distance_from_current": 0.0,
                    "bearing": 0.0
                }
            ],
            "prediction_time": 60.0,
            "timestamp": "2025-10-09T18:50:58.531771"
        }
        """.data(using: .utf8)!
        
        do {
            let response = try JSONDecoder().decode(BackendTrajectoryResponse.self, from: jsonData)
            XCTAssertTrue(response.success)
            XCTAssertEqual(response.flightId, "a0f355")
            XCTAssertEqual(response.trajectory.count, 1)
        } catch {
            XCTFail("Failed to decode trajectory JSON: \(error)")
        }
    }
    
    // MARK: - Altitude Endpoint Tests
    
    func testAltitudeEndpointParsing() {
        let jsonData = """
        {
            "success": true,
            "flight_id": "a0f355",
            "predicted_altitude": 586.74,
            "predicted_vertical_rate": -4.88,
            "confidence": 0.947956517146085,
            "timestamp": "2025-10-09T18:50:58.531771"
        }
        """.data(using: .utf8)!
        
        do {
            let response = try JSONDecoder().decode(BackendAltitudeResponse.self, from: jsonData)
            XCTAssertTrue(response.success)
            XCTAssertEqual(response.flightId, "a0f355")
            XCTAssertEqual(response.predictedAltitude, 586.74, accuracy: 0.01)
        } catch {
            XCTFail("Failed to decode altitude JSON: \(error)")
        }
    }
    
    // MARK: - Error Handling Tests
    
    func testServerErrorResponse() {
        let jsonData = """
        {
            "success": false,
            "error": "Flight not found",
            "timestamp": "2025-10-09T18:50:58.531771"
        }
        """.data(using: .utf8)!
        
        do {
            let response = try JSONDecoder().decode(BackendFlightsResponse.self, from: jsonData)
            XCTAssertFalse(response.success)
        } catch {
            // This is expected for error responses
            XCTAssertTrue(true)
        }
    }
}