import Foundation
import Combine

class OpenSkyService: ObservableObject {
    private let backendService = BackendService()
    
    @Published var flights: [Flight] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Subscribe to backend service updates
        backendService.$flights
            .assign(to: \.flights, on: self)
            .store(in: &cancellables)
        
        backendService.$isLoading
            .assign(to: \.isLoading, on: self)
            .store(in: &cancellables)
        
        backendService.$errorMessage
            .assign(to: \.errorMessage, on: self)
            .store(in: &cancellables)
    }
    
    func fetchFlights() {
        backendService.fetchFlights()
    }
    
    // MARK: - Backend Integration Methods
    
    func fetchFlightTrajectory(flightId: String, predictionTime: Double = 60.0) async throws -> [TrajectoryPoint] {
        return try await backendService.fetchFlightTrajectory(flightId: flightId, predictionTime: predictionTime)
    }
    
    func fetchAltitudePrediction(flightId: String) async throws -> AltitudePrediction {
        return try await backendService.fetchAltitudePrediction(flightId: flightId)
    }
    
    func checkBackendHealth() async -> Bool {
        return await backendService.checkBackendHealth()
    }
}
