import Foundation

// MARK: - Completion API  (data.geopf.fr/geocodage/completion)

struct CompletionResponse: Decodable, Sendable {
    let status: String?
    let results: [CompletionResult]

    enum CodingKeys: String, CodingKey {
        case status, results
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        status = try c.decodeIfPresent(String.self, forKey: .status)
        results = try c.decodeIfPresent([CompletionResult].self, forKey: .results) ?? []
    }
}

struct CompletionResult: Decodable, Sendable {
    let fulltext: String
    let x: Double       // longitude WGS84
    let y: Double       // latitude WGS84
    let classification: Int?
    let kind: String?
    // "country" is the result type field in this API (StreetAddress or PositionOfInterest)
    let country: String?
    let city: String?
    let zipcode: String?
    let department: String?

    var coordinate: Coordinate {
        Coordinate(latitude: y, longitude: x)
    }

    var displayLabel: String { fulltext }
}

// MARK: - Search API  (data.geopf.fr/geocodage/search) — GeoJSON

struct SearchFeatureCollection: Decodable, Sendable {
    let features: [SearchFeature]

    enum CodingKeys: String, CodingKey { case features }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        features = try c.decodeIfPresent([SearchFeature].self, forKey: .features) ?? []
    }
}

struct SearchFeature: Decodable, Sendable {
    let geometry: GeoJSONPoint?
    let properties: SearchProperties?

    var coordinate: Coordinate? {
        guard let g = geometry else { return nil }
        return Coordinate(latitude: g.latitude, longitude: g.longitude)
    }

    var label: String {
        properties?.label ?? properties?.name ?? ""
    }
}

struct GeoJSONPoint: Decodable, Sendable {
    let longitude: Double
    let latitude: Double

    enum CodingKeys: String, CodingKey { case coordinates }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let coords = try c.decode([Double].self, forKey: .coordinates)
        guard coords.count >= 2 else {
            throw DecodingError.dataCorruptedError(forKey: .coordinates, in: c,
                debugDescription: "Expected [lon, lat]")
        }
        longitude = coords[0]
        latitude = coords[1]
    }
}

struct SearchProperties: Decodable, Sendable {
    let label: String?
    let score: Double?
    let id: String?
    let type: String?
    let name: String?
    let postcode: String?
    let citycode: String?
    let city: String?
    let context: String?
    let importance: Double?
    let x: Double?
    let y: Double?
}

// MARK: - UI Model

struct GeocodingSuggestion: Identifiable, Hashable, Sendable {
    let id: String
    let displayText: String
    let coordinate: Coordinate?

    init(from result: CompletionResult) {
        id = result.fulltext
        displayText = result.fulltext
        coordinate = result.coordinate
    }

    init(from feature: SearchFeature) {
        id = feature.properties?.id ?? UUID().uuidString
        displayText = feature.label
        coordinate = feature.coordinate
    }
}
