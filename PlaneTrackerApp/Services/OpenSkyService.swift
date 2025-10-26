import Foundation
import Combine

class OpenSkyService: ObservableObject {
    @Published var flights: [Flight] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let session = URLSession.shared
    private var flightsCache: [Flight] = []
    private var cacheTimestamp: Date?
    private let cacheDuration: TimeInterval = 8.0
    
    // SF Bay Area bounding box
    private let minLat = 36.8
    private let maxLat = 38.8
    private let minLon = -123.8
    private let maxLon = -121.0
    
    func fetchFlights() {
        // ===== MOCK DATA MODE - DISABLED - USING REAL OPENSKY DATA =====
        // To re-enable mock data for testing, uncomment the block below
        // Uncomment this block to re-enable mock data for testing
        /*
        NSLog("🎭 OpenSkyService: Using MOCK data for testing")
        DispatchQueue.main.async {
            self.flights = self.generateMockFlights()
            self.flightsCache = self.flights
            self.cacheTimestamp = Date()
            self.isLoading = false
            self.errorMessage = nil
            NSLog("✅ OpenSkyService: Loaded \(self.flights.count) MOCK flights")
            return
        }
        */
        // ===== END MOCK DATA MODE =====
        
        NSLog("🌐 OpenSkyService: Fetching REAL flights from OpenSky API...")
        
        // Check cache first
        if let cacheTime = cacheTimestamp,
           Date().timeIntervalSince(cacheTime) < cacheDuration,
           !flightsCache.isEmpty {
            NSLog("💾 OpenSkyService: Using cached data (\(flightsCache.count) flights)")
            DispatchQueue.main.async {
                self.flights = self.flightsCache
                self.isLoading = false
                self.errorMessage = nil
            }
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        let urlString = "https://opensky-network.org/api/states/all?lamin=\(minLat)&lomin=\(minLon)&lamax=\(maxLat)&lomax=\(maxLon)"
        
        guard let url = URL(string: urlString) else {
            NSLog("❌ OpenSkyService: Invalid URL")
            errorMessage = "Invalid URL"
            isLoading = false
            return
        }
        
        NSLog("🌐 OpenSkyService: Fetching from \(url.absoluteString)")
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 10.0
        
        session.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    NSLog("❌ OpenSkyService: Network error - \(error.localizedDescription)")
                    self?.errorMessage = "Network error: \(error.localizedDescription)"
                    // Use cached data if available
                    if let cache = self?.flightsCache, !cache.isEmpty {
                        NSLog("💾 OpenSkyService: Using cached data due to error")
                        self?.flights = cache
                    }
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    NSLog("❌ OpenSkyService: Invalid response type")
                    self?.errorMessage = "Invalid response from server"
                    return
                }
                
                NSLog("📡 OpenSkyService: HTTP Status Code: \(httpResponse.statusCode)")
                
                guard let data = data else {
                    NSLog("❌ OpenSkyService: No data received")
                    self?.errorMessage = "No data received from server"
                    return
                }
                
                NSLog("📦 OpenSkyService: Received \(data.count) bytes")
                
                // Log raw response for debugging
                if let rawString = String(data: data, encoding: .utf8) {
                    NSLog("📄 OpenSkyService: Raw response (first 200 chars): \(String(rawString.prefix(200)))")
    }
    
                do {
                    NSLog("🔍 Attempting to decode OpenSky response...")
                    let response = try JSONDecoder().decode(OpenSkyResponse.self, from: data)
                    NSLog("✅ Decoded response object successfully")
                    let flights = self?.parseFlights(from: response) ?? []
                    NSLog("✅ OpenSkyService: Successfully fetched \(flights.count) flights")
                    self?.flights = flights
                    self?.flightsCache = flights
                    self?.cacheTimestamp = Date()
                    self?.errorMessage = nil
                } catch {
                    NSLog("❌ OpenSkyService: Failed to decode - \(error)")
                    if let decodingError = error as? DecodingError {
                        switch decodingError {
                        case .dataCorrupted(let context):
                            NSLog("❌ Data corrupted: \(context.debugDescription)")
                        case .keyNotFound(let key, let context):
                            NSLog("❌ Key '\(key)' not found: \(context.debugDescription)")
                        case .typeMismatch(let type, let context):
                            NSLog("❌ Type mismatch for type '\(type)': \(context.debugDescription)")
                        case .valueNotFound(let type, let context):
                            NSLog("❌ Value not found for type '\(type)': \(context.debugDescription)")
                        @unknown default:
                            NSLog("❌ Unknown decoding error")
                        }
                    }
                    self?.errorMessage = "API response format error"
                }
            }
        }.resume()
    }
    
    private func parseFlights(from response: OpenSkyResponse) -> [Flight] {
        guard let states = response.states else {
            NSLog("⚠️ No states array in OpenSky response")
            return []
        }
        
        NSLog("📊 OpenSkyService: Parsing \(states.count) flight states...")
        
        return states.compactMap { state in
            // State array indices from OpenSky API
            guard state.count >= 17 else {
                NSLog("⚠️ State array too short: \(state.count) elements")
                return nil
            }
            
            guard let icao24 = state[0] as? String,
                  let callsign = state[1] as? String,
                  let originCountry = state[2] as? String,
                  let lastContact = state[4] as? Int else {
                NSLog("⚠️ Failed to parse required fields for state")
                return nil
            }
            
            let timePosition = state[3] as? Int
            let longitude = state[5] as? Double
            let latitude = state[6] as? Double
            let baroAltitude = state[7] as? Double
            let onGround = state[8] as? Bool ?? false
            let velocity = state[9] as? Double
            let trueTrack = state[10] as? Double
            let verticalRate = state[11] as? Double
            let geoAltitude = state[13] as? Double
            let squawk = state[14] as? String
            let spi = state[15] as? Bool ?? false
            let positionSource = state[16] as? Int ?? 0
            
            // Skip flights without position data
            guard longitude != nil, latitude != nil else {
                NSLog("⚠️ Skipping flight without position: \(callsign)")
                return nil
            }
            
            // Skip flights on ground
            guard !onGround else {
                NSLog("⚠️ Skipping ground flight: \(callsign)")
                return nil
            }
            
            NSLog("✅ Parsed flight: \(callsign) at (\(latitude!), \(longitude!)) alt=\(baroAltitude ?? 0)")
            
            return Flight(
                id: icao24,
                callsign: callsign.trimmingCharacters(in: .whitespaces),
                originCountry: originCountry,
                timePosition: timePosition,
                lastContact: lastContact,
                longitude: longitude,
                latitude: latitude,
                baroAltitude: baroAltitude,
                onGround: onGround,
                velocity: velocity,
                trueTrack: trueTrack,
                verticalRate: verticalRate,
                sensors: nil,
                geoAltitude: geoAltitude,
                squawk: squawk,
                spi: spi,
                positionSource: positionSource
            )
        }
    }
    
    // ===== MOCK DATA GENERATION - REMOVE THIS SECTION WHEN OPENSKY IS WORKING =====
    private func generateMockFlights() -> [Flight] {
        let currentTime = Int(Date().timeIntervalSince1970)
        
        // Reference point: Pier 39, San Francisco
        let pier39Lat = 37.8087
        let pier39Lon = -122.4098
        
        return [
            // Flight 1: Directly overhead Pier 39, medium altitude
            Flight(id: "a12345", callsign: "SWA1234", originCountry: "United States",
                   timePosition: currentTime - 5, lastContact: currentTime,
                   longitude: pier39Lon, latitude: pier39Lat,
                   baroAltitude: 3048.0, onGround: false,
                   velocity: 230.0, trueTrack: 90.0, verticalRate: 0.0,
                   sensors: nil, geoAltitude: 3070.0, squawk: "1234", spi: false, positionSource: 0),
            
            // Flight 2: Just north of Pier 39
            Flight(id: "a23456", callsign: "UAL5678", originCountry: "United States",
                   timePosition: currentTime - 3, lastContact: currentTime,
                   longitude: pier39Lon, latitude: pier39Lat + 0.01,
                   baroAltitude: 2438.4, onGround: false,
                   velocity: 200.0, trueTrack: 180.0, verticalRate: -5.0,
                   sensors: nil, geoAltitude: 2450.0, squawk: "5678", spi: false, positionSource: 0),
            
            // Flight 3: Just south of Pier 39
            Flight(id: "a34567", callsign: "ASA9012", originCountry: "United States",
                   timePosition: currentTime - 2, lastContact: currentTime,
                   longitude: pier39Lon, latitude: pier39Lat - 0.01,
                   baroAltitude: 2743.2, onGround: false,
                   velocity: 180.0, trueTrack: 0.0, verticalRate: 8.0,
                   sensors: nil, geoAltitude: 2760.0, squawk: "9012", spi: false, positionSource: 0),
            
            // Flight 4: Just east of Pier 39
            Flight(id: "a45678", callsign: "DAL3456", originCountry: "United States",
                   timePosition: currentTime - 4, lastContact: currentTime,
                   longitude: pier39Lon + 0.01, latitude: pier39Lat,
                   baroAltitude: 3352.8, onGround: false,
                   velocity: 220.0, trueTrack: 270.0, verticalRate: 0.0,
                   sensors: nil, geoAltitude: 3370.0, squawk: "3456", spi: false, positionSource: 0),
            
            // Flight 5: Just west of Pier 39 (over water)
            Flight(id: "a56789", callsign: "JBU7890", originCountry: "United States",
                   timePosition: currentTime - 6, lastContact: currentTime,
                   longitude: pier39Lon - 0.01, latitude: pier39Lat,
                   baroAltitude: 3657.6, onGround: false,
                   velocity: 250.0, trueTrack: 90.0, verticalRate: 0.0,
                   sensors: nil, geoAltitude: 3680.0, squawk: "7890", spi: false, positionSource: 0),
            
            // Flight 6: Northeast of Pier 39
            Flight(id: "a67890", callsign: "AAL2345", originCountry: "United States",
                   timePosition: currentTime - 3, lastContact: currentTime,
                   longitude: pier39Lon + 0.008, latitude: pier39Lat + 0.008,
                   baroAltitude: 2133.6, onGround: false,
                   velocity: 210.0, trueTrack: 225.0, verticalRate: -3.0,
                   sensors: nil, geoAltitude: 2150.0, squawk: "2345", spi: false, positionSource: 0),
            
            // Flight 7: Northwest of Pier 39
            Flight(id: "a78901", callsign: "NKS6789", originCountry: "United States",
                   timePosition: currentTime - 5, lastContact: currentTime,
                   longitude: pier39Lon - 0.008, latitude: pier39Lat + 0.008,
                   baroAltitude: 4267.2, onGround: false,
                   velocity: 205.0, trueTrack: 135.0, verticalRate: 0.0,
                   sensors: nil, geoAltitude: 4290.0, squawk: "6789", spi: false, positionSource: 0),
            
            // Flight 8: Southeast of Pier 39
            Flight(id: "a89012", callsign: "FFT4567", originCountry: "United States",
                   timePosition: currentTime - 2, lastContact: currentTime,
                   longitude: pier39Lon + 0.008, latitude: pier39Lat - 0.008,
                   baroAltitude: 1828.8, onGround: false,
                   velocity: 190.0, trueTrack: 315.0, verticalRate: 10.0,
                   sensors: nil, geoAltitude: 1850.0, squawk: "4567", spi: false, positionSource: 0),
            
            // Flight 9: Southwest of Pier 39
            Flight(id: "a90123", callsign: "FDX8901", originCountry: "United States",
                   timePosition: currentTime - 7, lastContact: currentTime,
                   longitude: pier39Lon - 0.008, latitude: pier39Lat - 0.008,
                   baroAltitude: 3962.4, onGround: false,
                   velocity: 240.0, trueTrack: 45.0, verticalRate: 0.0,
                   sensors: nil, geoAltitude: 3980.0, squawk: "8901", spi: false, positionSource: 0),
            
            // Flight 10: High altitude directly over Pier 39
            Flight(id: "a01234", callsign: "N123AB", originCountry: "United States",
                   timePosition: currentTime - 1, lastContact: currentTime,
                   longitude: pier39Lon, latitude: pier39Lat,
                   baroAltitude: 4572.0, onGround: false,
                   velocity: 150.0, trueTrack: 180.0, verticalRate: 0.0,
                   sensors: nil, geoAltitude: 4600.0, squawk: "1200", spi: false, positionSource: 0)
        ]
    }
    // ===== END MOCK DATA GENERATION =====
}

// MARK: - OpenSky API Response Model

struct OpenSkyResponse: Decodable {
    let time: Int?
    let states: [[Any]]?
    
    enum CodingKeys: String, CodingKey {
        case time
        case states
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        time = try container.decodeIfPresent(Int.self, forKey: .time)
        
        // Decode states as array of mixed types
        do {
            if let statesArray = try container.decodeIfPresent([[AnyCodable]].self, forKey: .states) {
                NSLog("✅ Successfully decoded \(statesArray.count) flight states")
                states = statesArray.map { $0.map { $0.value } }
            } else {
                NSLog("⚠️ States array is nil")
                states = nil
            }
        } catch {
            NSLog("❌ Failed to decode states array: \(error)")
            states = nil
        }
    }
}
