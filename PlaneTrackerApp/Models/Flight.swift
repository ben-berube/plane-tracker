import Foundation

struct Flight: Codable, Identifiable {
    let id: String
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
    
    enum CodingKeys: String, CodingKey {
        case id = "icao24"
        case callsign
        case originCountry
        case timePosition
        case lastContact
        case longitude
        case latitude
        case baroAltitude
        case onGround
        case velocity
        case trueTrack
        case verticalRate
        case sensors
        case geoAltitude
        case squawk
        case spi
        case positionSource
    }
}

struct FlightResponse: Codable {
    let time: Int
    let states: [[AnyCodable]]?
}

struct AnyCodable: Codable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let intValue = try? container.decode(Int.self) {
            value = intValue
        } else if let doubleValue = try? container.decode(Double.self) {
            value = doubleValue
        } else if let stringValue = try? container.decode(String.self) {
            value = stringValue
        } else if let boolValue = try? container.decode(Bool.self) {
            value = boolValue
        } else if let arrayValue = try? container.decode([AnyCodable].self) {
            value = arrayValue.map { $0.value }
        } else {
            throw DecodingError.typeMismatch(Any.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unsupported type"))
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        if let intValue = value as? Int {
            try container.encode(intValue)
        } else if let doubleValue = value as? Double {
            try container.encode(doubleValue)
        } else if let stringValue = value as? String {
            try container.encode(stringValue)
        } else if let boolValue = value as? Bool {
            try container.encode(boolValue)
        } else if let arrayValue = value as? [Any] {
            try container.encode(arrayValue.map { AnyCodable($0) })
        }
    }
}
