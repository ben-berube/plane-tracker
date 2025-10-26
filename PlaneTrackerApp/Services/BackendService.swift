import Foundation
import Combine

class BackendService: ObservableObject {
    private var baseURL: String {
        #if DEBUG
        return "http://10.103.2.222:8000"
        #else
        return "https://your-production-backend.com"
        #endif
    }
    private let session = URLSession.shared
    
    // Caching
    private var flightsCache: [Flight] = []
    private var cacheTimestamp: Date?
    private let cacheDuration: TimeInterval = 8.0 // 8 seconds to match backend
    
    @Published var flights: [Flight] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // MARK: - Public Methods
    
    func fetchFlights() {
        NSLog("🔵 BackendService.fetchFlights() called")
        // Check cache first
        if let cacheTime = cacheTimestamp,
           Date().timeIntervalSince(cacheTime) < cacheDuration,
           !flightsCache.isEmpty {
            NSLog("💾 BackendService: Using cached data (%d flights)", flightsCache.count)
            DispatchQueue.main.async {
                self.flights = self.flightsCache
                self.isLoading = false
                self.errorMessage = nil
            }
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        guard let url = URL(string: "\(baseURL)/api/flights") else {
            NSLog("❌ BackendService: Invalid URL")
            errorMessage = "Invalid URL"
            isLoading = false
            return
        }
        
        NSLog("🌐 BackendService: Fetching from %@", url.absoluteString)
        
        session.dataTask(with: url) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    NSLog("❌ BackendService: Network error - %@", error.localizedDescription)
                    self?.errorMessage = error.localizedDescription
                    // Return cached data if available
                    if let cache = self?.flightsCache, !cache.isEmpty {
                        NSLog("💾 BackendService: Using cached data due to error")
                        self?.flights = cache
                    }
                    return
                }
                
                guard let data = data else {
                    self?.errorMessage = "No data received"
                    return
                }
                
                do {
                    let response = try JSONDecoder().decode(BackendFlightsResponse.self, from: data)
                    if response.success {
                        let flights = response.flights.map { Flight(from: $0) }
                        NSLog("✅✅✅ BackendService: Successfully fetched %d flights", flights.count)
                        self?.flights = flights
                        self?.flightsCache = flights
                        self?.cacheTimestamp = Date()
                        self?.errorMessage = nil
                    } else {
                        NSLog("❌ BackendService: Backend returned success=false")
                        self?.errorMessage = "Backend error"
                    }
                } catch {
                    NSLog("❌ BackendService: Failed to decode - %@", error.localizedDescription)
                    self?.errorMessage = "Failed to decode response: \(error.localizedDescription)"
                }
            }
        }.resume()
    }
    
    func fetchFlightTrajectory(flightId: String, predictionTime: Double = 60.0) async throws -> [TrajectoryPoint] {
        guard let url = URL(string: "\(baseURL)/api/flights/\(flightId)/trajectory?time=\(predictionTime)") else {
            throw BackendError.invalidURL
        }
        
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw BackendError.serverError
        }
        
        let trajectoryResponse = try JSONDecoder().decode(BackendTrajectoryResponse.self, from: data)
        
        if trajectoryResponse.success {
            return trajectoryResponse.trajectory.map { TrajectoryPoint(from: $0) }
        } else {
            throw BackendError.serverError
        }
    }
    
    func fetchAltitudePrediction(flightId: String) async throws -> AltitudePrediction {
        guard let url = URL(string: "\(baseURL)/api/flights/\(flightId)/altitude") else {
            throw BackendError.invalidURL
        }
        
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw BackendError.serverError
        }
        
        let altitudeResponse = try JSONDecoder().decode(BackendAltitudeResponse.self, from: data)
        
        if altitudeResponse.success {
            return AltitudePrediction(
                altitude: altitudeResponse.predictedAltitude,
                verticalRate: altitudeResponse.predictedVerticalRate,
                confidence: altitudeResponse.confidence
            )
        } else {
            throw BackendError.serverError
        }
    }
    
    // MARK: - Health Check
    
    func checkBackendHealth() async -> Bool {
        guard let url = URL(string: "\(baseURL)/api/health") else {
            return false
        }
        
        do {
            let (_, response) = try await session.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse else {
                return false
            }
            return httpResponse.statusCode == 200
        } catch {
            return false
        }
    }
}

// MARK: - Data Models

struct BackendFlightsResponse: Codable {
    let success: Bool
    let flights: [BackendFlight]
    let count: Int
    let timestamp: String
}

struct BackendFlight: Codable {
    let icao24: String
    let callsign: String
    let originCountry: String
    let timePosition: Int?
    let lastContact: Int
    let longitude: Double?
    let latitude: Double?
    let baroAltitude: Double?
    let onGround: Bool
    let velocity: Double?
    let trueTrack: Double?
    let verticalRate: Double?
    let sensors: [Int]?
    let geoAltitude: Double?
    let squawk: String?
    let spi: Bool
    let positionSource: Int
    
    // Backend enhanced fields
    let predictedAltitude: Double?
    let altitudeConfidence: Double?
    let hasPredictedAltitude: Bool?
    let predictedTrajectory: [[String: AnyCodable]]?
    
    enum CodingKeys: String, CodingKey {
        case icao24, callsign, originCountry, timePosition, lastContact
        case longitude, latitude, baroAltitude, onGround, velocity
        case trueTrack, verticalRate, sensors, geoAltitude, squawk, spi, positionSource
        case predictedAltitude, altitudeConfidence, hasPredictedAltitude, predictedTrajectory
    }
}

struct BackendTrajectoryResponse: Codable {
    let success: Bool
    let flightId: String
    let trajectory: [BackendTrajectoryPoint]
    let predictionTime: Double
    let timestamp: String
    
    enum CodingKeys: String, CodingKey {
        case success, flightId = "flight_id", trajectory, predictionTime = "prediction_time", timestamp
    }
}

struct BackendTrajectoryPoint: Codable {
    let latitude: Double
    let longitude: Double
    let altitude: Double
    let timeOffset: Double
    let distanceFromCurrent: Double
    let bearing: Double
    
    enum CodingKeys: String, CodingKey {
        case latitude, longitude, altitude, timeOffset = "time_offset"
        case distanceFromCurrent = "distance_from_current", bearing
    }
}

struct BackendAltitudeResponse: Codable {
    let success: Bool
    let flightId: String
    let predictedAltitude: Double
    let predictedVerticalRate: Double
    let confidence: Double
    let timestamp: String
    
    enum CodingKeys: String, CodingKey {
        case success, flightId = "flight_id", predictedAltitude = "predicted_altitude"
        case predictedVerticalRate = "predicted_vertical_rate", confidence, timestamp
    }
}

struct AltitudePrediction {
    let altitude: Double
    let verticalRate: Double
    let confidence: Double
}

// MARK: - Extensions

extension Flight {
    init(from backendFlight: BackendFlight) {
        self.id = backendFlight.icao24
        self.callsign = backendFlight.callsign
        self.originCountry = backendFlight.originCountry
        self.timePosition = backendFlight.timePosition
        self.lastContact = backendFlight.lastContact
        self.longitude = backendFlight.longitude
        self.latitude = backendFlight.latitude
        self.baroAltitude = backendFlight.baroAltitude
        self.onGround = backendFlight.onGround
        self.velocity = backendFlight.velocity
        self.trueTrack = backendFlight.trueTrack
        self.verticalRate = backendFlight.verticalRate
        self.sensors = backendFlight.sensors
        self.geoAltitude = backendFlight.geoAltitude
        self.squawk = backendFlight.squawk
        self.spi = backendFlight.spi
        self.positionSource = backendFlight.positionSource
        
        // Backend enhanced fields
        self.predictedAltitude = backendFlight.predictedAltitude
        self.altitudeConfidence = backendFlight.altitudeConfidence
        self.hasPredictedAltitude = backendFlight.hasPredictedAltitude ?? false
        self.predictedTrajectory = backendFlight.predictedTrajectory?.map { dict in
            dict.mapValues { $0.value }
        }
    }
}

extension TrajectoryPoint {
    init(from backendPoint: BackendTrajectoryPoint) {
        self.latitude = backendPoint.latitude
        self.longitude = backendPoint.longitude
        self.altitude = backendPoint.altitude
        self.timeOffset = backendPoint.timeOffset
        self.distanceFromCurrent = backendPoint.distanceFromCurrent
        self.bearing = backendPoint.bearing
    }
}

// MARK: - Errors

enum BackendError: Error, LocalizedError {
    case invalidURL
    case serverError
    case networkError
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .serverError:
            return "Server error"
        case .networkError:
            return "Network error"
        }
    }
}
