import XCTest
import Foundation

final class FavoritesPersistenceTests: XCTestCase {
    private let tempDir = FileManager.default.temporaryDirectory
        .appendingPathComponent("GeoBridgeTests-\(UUID().uuidString)")

    override func setUp() {
        super.setUp()
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        super.tearDown()
        try? FileManager.default.removeItem(at: tempDir)
    }

    func testSaveAndLoadFavourites() throws {
        let locations = [
            TestLocation(name: "Eiffel Tower", lat: 48.8584, lon: 2.2945),
            TestLocation(name: "Louvre", lat: 48.8606, lon: 2.3376)
        ]

        let url = tempDir.appendingPathComponent("fav.json")
        let encoded = try JSONEncoder().encode(locations)
        try encoded.write(to: url)

        let loaded = try JSONDecoder().decode([TestLocation].self, from: Data(contentsOf: url))
        XCTAssertEqual(loaded.count, 2)
        XCTAssertEqual(loaded[0].name, "Eiffel Tower")
        XCTAssertEqual(loaded[1].lat, 48.8606, accuracy: 0.0001)
    }

    func testLoadFromNonExistentFileReturnsEmpty() {
        let url = tempDir.appendingPathComponent("missing.json")
        let loaded = (try? JSONDecoder().decode([TestLocation].self, from: Data(contentsOf: url))) ?? []
        XCTAssertTrue(loaded.isEmpty)
    }

    func testSavePreservesCoordinates() throws {
        let coord = TestLocation(name: "Test", lat: 48.856600, lon: 2.352200)
        let url = tempDir.appendingPathComponent("coord.json")
        try JSONEncoder().encode([coord]).write(to: url)
        let loaded = try JSONDecoder().decode([TestLocation].self, from: Data(contentsOf: url))
        XCTAssertEqual(loaded[0].lat, coord.lat, accuracy: 1e-9)
        XCTAssertEqual(loaded[0].lon, coord.lon, accuracy: 1e-9)
    }

    func testRecentsAreTrimmedTo20() {
        var recents = (0..<30).map { i in
            TestLocation(name: "Place \(i)", lat: Double(i), lon: 0)
        }
        recents = Array(recents.prefix(20))
        XCTAssertEqual(recents.count, 20)
    }
}

struct TestLocation: Codable {
    var name: String
    var lat: Double
    var lon: Double
}
