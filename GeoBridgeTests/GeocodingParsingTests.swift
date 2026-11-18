import XCTest
import Foundation

final class GeocodingParsingTests: XCTestCase {
    private let decoder = JSONDecoder()

    // MARK: - Completion API

    func testCompletionResponseParsesResults() throws {
        let data = try fixture("geocoding_completion")
        let response = try decoder.decode(TestCompletionResponse.self, from: data)
        XCTAssertEqual(response.status, "OK")
        XCTAssertFalse(response.results.isEmpty)
    }

    func testCompletionResultHasFulltext() throws {
        let data = try fixture("geocoding_completion")
        let response = try decoder.decode(TestCompletionResponse.self, from: data)
        guard let first = response.results.first else {
            return XCTFail("Expected at least one result")
        }
        XCTAssertFalse(first.fulltext.isEmpty)
    }

    func testCompletionCoordinatesAreWGS84() throws {
        let data = try fixture("geocoding_completion")
        let response = try decoder.decode(TestCompletionResponse.self, from: data)
        for result in response.results {
            XCTAssertTrue(result.y >= -90 && result.y <= 90,
                          "latitude (y) out of range: \(result.y)")
            XCTAssertTrue(result.x >= -180 && result.x <= 180,
                          "longitude (x) out of range: \(result.x)")
        }
    }

    // MARK: - Search (GeoJSON)

    func testSearchResponseParsesFeatures() throws {
        let data = try fixture("geocoding_search")
        let collection = try decoder.decode(TestFeatureCollection.self, from: data)
        XCTAssertFalse(collection.features.isEmpty)
    }

    func testSearchFeatureHasCoordinates() throws {
        let data = try fixture("geocoding_search")
        let collection = try decoder.decode(TestFeatureCollection.self, from: data)
        guard let first = collection.features.first else {
            return XCTFail("Expected at least one feature")
        }
        XCTAssertNotNil(first.geometry)
        XCTAssertFalse(first.properties?.label?.isEmpty ?? true)
    }

    func testSearchCoordinatesAreWGS84() throws {
        let data = try fixture("geocoding_search")
        let collection = try decoder.decode(TestFeatureCollection.self, from: data)
        for feature in collection.features {
            if let geo = feature.geometry {
                XCTAssertTrue(geo.latitude >= -90 && geo.latitude <= 90)
                XCTAssertTrue(geo.longitude >= -180 && geo.longitude <= 180)
            }
        }
    }

    // MARK: - Empty response resilience

    func testEmptyResultsDoNotCrash() throws {
        let json = #"{"status":"OK","results":[]}"#.data(using: .utf8)!
        let response = try decoder.decode(TestCompletionResponse.self, from: json)
        XCTAssertTrue(response.results.isEmpty)
    }

    func testMissingStatusFieldDoesNotCrash() throws {
        let json = #"{"results":[]}"#.data(using: .utf8)!
        let response = try decoder.decode(TestCompletionResponse.self, from: json)
        XCTAssertNil(response.status)
        XCTAssertTrue(response.results.isEmpty)
    }

    // MARK: - Helpers

    private func fixture(_ name: String) throws -> Data {
        let bundle = Bundle(for: type(of: self))
        guard let url = bundle.url(forResource: name, withExtension: "json") else {
            // Fall back to loading from Fixtures subdirectory next to test file
            let fileURL = URL(fileURLWithPath: #file)
                .deletingLastPathComponent()
                .appendingPathComponent("Fixtures/\(name).json")
            return try Data(contentsOf: fileURL)
        }
        return try Data(contentsOf: url)
    }
}

// MARK: - Lightweight test-local decodable models

struct TestCompletionResponse: Decodable {
    let status: String?
    let results: [TestCompletionResult]

    enum CodingKeys: String, CodingKey { case status, results }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        status = try c.decodeIfPresent(String.self, forKey: .status)
        results = try c.decodeIfPresent([TestCompletionResult].self, forKey: .results) ?? []
    }
}

struct TestCompletionResult: Decodable {
    let fulltext: String
    let x: Double
    let y: Double
    let classification: Int?
    let kind: String?
}

struct TestFeatureCollection: Decodable {
    let features: [TestFeature]
    enum CodingKeys: String, CodingKey { case features }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        features = try c.decodeIfPresent([TestFeature].self, forKey: .features) ?? []
    }
}

struct TestFeature: Decodable {
    let geometry: TestGeoPoint?
    let properties: TestProperties?
}

struct TestGeoPoint: Decodable {
    let longitude: Double
    let latitude: Double
    enum CodingKeys: String, CodingKey { case coordinates }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let coords = try c.decode([Double].self, forKey: .coordinates)
        guard coords.count >= 2 else { throw DecodingError.dataCorruptedError(forKey: .coordinates, in: c, debugDescription: "") }
        longitude = coords[0]; latitude = coords[1]
    }
}

struct TestProperties: Decodable {
    let label: String?
    let score: Double?
    let type: String?
}
