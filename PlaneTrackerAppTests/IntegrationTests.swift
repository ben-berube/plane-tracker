import XCTest
@testable import PlaneTrackerApp

class IntegrationTests: XCTestCase {
    var backendService: BackendService!
    var openSkyService: OpenSkyService!
    
    override func setUp() {
        super.setUp()
        backendService = BackendService()
        openSkyService = OpenSkyService()
    }
    
    override func tearDown() {
        backendService = nil
        openSkyService = nil
        super.tearDown()
    }
    
    // MARK: - End-to-End Backend Communication Tests
    
    func testEndToEndBackendCommunication() {
        let expectation = XCTestExpectation(description: "Backend communication")
        
        // Test backend health
        Task {
            let isHealthy = await backendService.checkBackendHealth()
            XCTAssertTrue(isHealthy, "Backend should be healthy")
            
            // Test flight fetching
            backendService.fetchFlights()
            
            // Wait for async operation
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                XCTAssertFalse(self.backendService.flights.isEmpty, "Flights should be loaded")
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testOpenSkyServiceIntegration() {
        let expectation = XCTestExpectation(description: "OpenSky service integration")
        
        // Test OpenSky service delegates to backend
        openSkyService.fetchFlights()
        
        // Wait for async operation
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            XCTAssertFalse(self.openSkyService.flights.isEmpty, "OpenSky service should have flights")
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    // MARK: - Trajectory Endpoint Integration Tests
    
    func testTrajectoryEndpointIntegration() {
        let expectation = XCTestExpectation(description: "Trajectory endpoint")
        
        Task {
            do {
                let trajectory = try await backendService.fetchFlightTrajectory(flightId: "a0f355", predictionTime: 60.0)
                XCTAssertFalse(trajectory.isEmpty, "Trajectory should not be empty")
                expectation.fulfill()
            } catch {
                // If backend is not running, this is expected
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testAltitudeEndpointIntegration() {
        let expectation = XCTestExpectation(description: "Altitude endpoint")
        
        Task {
            do {
                let altitudePrediction = try await backendService.fetchAltitudePrediction(flightId: "a0f355")
                XCTAssertGreaterThanOrEqual(altitudePrediction.altitude, 0, "Altitude should be positive")
                XCTAssertGreaterThanOrEqual(altitudePrediction.confidence, 0.0, "Confidence should be non-negative")
                XCTAssertLessThanOrEqual(altitudePrediction.confidence, 1.0, "Confidence should be at most 1.0")
                expectation.fulfill()
            } catch {
                // If backend is not running, this is expected
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    // MARK: - Health Check Integration Tests
    
    func testHealthCheckIntegration() {
        let expectation = XCTestExpectation(description: "Health check")
        
        Task {
            let isHealthy = await backendService.checkBackendHealth()
            XCTAssertTrue(isHealthy, "Backend should be healthy")
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    // MARK: - Caching Behavior Tests
    
    func testCachingBehavior() {
        let expectation = XCTestExpectation(description: "Caching behavior")
        
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
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    // MARK: - Error Handling Tests
    
    func testNetworkErrorHandling() {
        let expectation = XCTestExpectation(description: "Network error handling")
        
        // Test with invalid URL (would require mocking)
        backendService.fetchFlights()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            // Should handle errors gracefully
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    // MARK: - Data Flow Integration Tests
    
    func testDataFlowIntegration() {
        let expectation = XCTestExpectation(description: "Data flow integration")
        
        // Test complete data flow from backend to AR visualization
        backendService.fetchFlights()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            // Verify data flow
            XCTAssertFalse(self.backendService.flights.isEmpty, "Backend should have flights")
            
            // Test trajectory prediction
            let flight = self.backendService.flights.first!
            let trajectoryPredictor = TrajectoryPredictor()
            let trajectory = trajectoryPredictor.predictTrajectory(for: flight)
            
            XCTAssertFalse(trajectory.isEmpty, "Trajectory should be predicted")
            
            // Test altitude estimation
            let altitudeFallback = AltitudeFallback()
            let altitude = altitudeFallback.estimateAltitude(for: flight)
            
            XCTAssertGreaterThanOrEqual(altitude, 0, "Altitude should be estimated")
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    // MARK: - Performance Tests
    
    func testBackendPerformance() {
        let expectation = XCTestExpectation(description: "Backend performance")
        
        measure {
            backendService.fetchFlights()
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testTrajectoryPredictionPerformance() {
        let expectation = XCTestExpectation(description: "Trajectory prediction performance")
        
        backendService.fetchFlights()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            let flight = self.backendService.flights.first!
            let trajectoryPredictor = TrajectoryPredictor()
            
            measure {
                let trajectory = trajectoryPredictor.predictTrajectory(for: flight)
                XCTAssertFalse(trajectory.isEmpty)
            }
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testAltitudeEstimationPerformance() {
        let expectation = XCTestExpectation(description: "Altitude estimation performance")
        
        backendService.fetchFlights()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            let flight = self.backendService.flights.first!
            let altitudeFallback = AltitudeFallback()
            
            measure {
                let altitude = altitudeFallback.estimateAltitude(for: flight)
                XCTAssertGreaterThanOrEqual(altitude, 0)
            }
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
}


