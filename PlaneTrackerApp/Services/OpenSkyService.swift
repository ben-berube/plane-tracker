import Foundation
import Combine

class OpenSkyService: ObservableObject {
    private let baseURL = "https://opensky-network.org/api"
    private let session = URLSession.shared
    
    // San Francisco Bay Area bounds
    private let sfBayBounds = BoundingBox(
        minLatitude: 37.4,
        maxLatitude: 38.0,
        minLongitude: -122.6,
        maxLongitude: -121.8
    )
    
    @Published var flights: [Flight] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    func fetchFlights() {
        isLoading = true
        errorMessage = nil
        
        let urlString = "\(baseURL)/states/all?lamin=\(sfBayBounds.minLatitude)&lomin=\(sfBayBounds.minLongitude)&lamax=\(sfBayBounds.maxLatitude)&lomax=\(sfBayBounds.maxLongitude)"
        
        guard let url = URL(string: urlString) else {
            errorMessage = "Invalid URL"
            isLoading = false
            return
        }
        
        session.dataTask(with: url) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    self?.errorMessage = error.localizedDescription
                    return
                }
                
                guard let data = data else {
                    self?.errorMessage = "No data received"
                    return
                }
                
                do {
                    let response = try JSONDecoder().decode(FlightResponse.self, from: data)
                    self?.flights = self?.parseFlights(from: response) ?? []
                } catch {
                    self?.errorMessage = "Failed to decode response: \(error.localizedDescription)"
                }
            }
        }.resume()
    }
    
    private func parseFlights(from response: FlightResponse) -> [Flight] {
        guard let states = response.states else { return [] }
        
        return states.compactMap { state in
            guard state.count >= 17 else { return nil }
            
            return Flight(
                id: state[0].value as? String ?? "",
                callsign: state[1].value as? String ?? "",
                originCountry: state[2].value as? String ?? "",
                timePosition: state[3].value as? Int,
                lastContact: state[4].value as? Int ?? 0,
                longitude: state[5].value as? Double,
                latitude: state[6].value as? Double,
                baroAltitude: state[7].value as? Double,
                onGround: state[8].value as? Bool ?? false,
                velocity: state[9].value as? Double,
                trueTrack: state[10].value as? Double,
                verticalRate: state[11].value as? Double,
                sensors: state[12].value as? [Int],
                geoAltitude: state[13].value as? Double,
                squawk: state[14].value as? String,
                spi: state[15].value as? Bool ?? false,
                positionSource: state[16].value as? Int ?? 0
            )
        }
    }
}

struct BoundingBox {
    let minLatitude: Double
    let maxLatitude: Double
    let minLongitude: Double
    let maxLongitude: Double
}
