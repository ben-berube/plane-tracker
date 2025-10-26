import Foundation

struct Flight: Identifiable {
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
    
    // Backend enhanced fields
    let predictedAltitude: Double?
    let altitudeConfidence: Double?
    let hasPredictedAltitude: Bool
    let predictedTrajectory: [[String: Any]]?
    
    // Custom initializer for backward compatibility
    init(id: String, callsign: String, originCountry: String, timePosition: Int?, lastContact: Int, longitude: Double?, latitude: Double?, baroAltitude: Double?, onGround: Bool, velocity: Double?, trueTrack: Double?, verticalRate: Double?, sensors: [Int]?, geoAltitude: Double?, squawk: String?, spi: Bool, positionSource: Int) {
        self.id = id
        self.callsign = callsign
        self.originCountry = originCountry
        self.timePosition = timePosition
        self.lastContact = lastContact
        self.longitude = longitude
        self.latitude = latitude
        self.baroAltitude = baroAltitude
        self.onGround = onGround
        self.velocity = velocity
        self.trueTrack = trueTrack
        self.verticalRate = verticalRate
        self.sensors = sensors
        self.geoAltitude = geoAltitude
        self.squawk = squawk
        self.spi = spi
        self.positionSource = positionSource
        self.predictedAltitude = nil
        self.altitudeConfidence = nil
        self.hasPredictedAltitude = false
        self.predictedTrajectory = nil
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
        
        // Check for null values first
        if container.decodeNil() {
            value = NSNull()
            return
        }
        
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
            // If all else fails, store as null instead of throwing
            value = NSNull()
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
