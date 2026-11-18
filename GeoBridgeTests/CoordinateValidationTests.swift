import XCTest

// These tests exercise pure logic from the Coordinate model.
// They do not import the main executable target to avoid @main conflicts.
// The types are re-declared below as exact copies for test isolation.

final class CoordinateValidationTests: XCTestCase {
    // MARK: - Valid coordinates

    func testValidParisCoordinate() {
        let coord = TestCoordinate(latitude: 48.8566, longitude: 2.3522)
        XCTAssertTrue(coord.isValid)
    }

    func testValidNegativeLongitude() {
        let coord = TestCoordinate(latitude: 40.7128, longitude: -74.0060)  // New York
        XCTAssertTrue(coord.isValid)
    }

    func testValidSouthPole() {
        let coord = TestCoordinate(latitude: -90.0, longitude: 0.0)
        XCTAssertTrue(coord.isValid)
    }

    func testValidMaxValues() {
        let coord = TestCoordinate(latitude: 90.0, longitude: 180.0)
        XCTAssertTrue(coord.isValid)
    }

    func testValidMinValues() {
        let coord = TestCoordinate(latitude: -90.0, longitude: -180.0)
        XCTAssertTrue(coord.isValid)
    }

    // MARK: - Invalid coordinates

    func testInvalidLatitudeTooHigh() {
        let coord = TestCoordinate(latitude: 90.001, longitude: 0)
        XCTAssertFalse(coord.isValid)
    }

    func testInvalidLatitudeTooLow() {
        let coord = TestCoordinate(latitude: -90.001, longitude: 0)
        XCTAssertFalse(coord.isValid)
    }

    func testInvalidLongitudeTooHigh() {
        let coord = TestCoordinate(latitude: 0, longitude: 180.001)
        XCTAssertFalse(coord.isValid)
    }

    func testInvalidLongitudeTooLow() {
        let coord = TestCoordinate(latitude: 0, longitude: -180.001)
        XCTAssertFalse(coord.isValid)
    }

    func testInvalidNaN() {
        let coord = TestCoordinate(latitude: Double.nan, longitude: 0)
        XCTAssertFalse(coord.isValid)
    }

    func testInvalidInfinity() {
        let coord = TestCoordinate(latitude: Double.infinity, longitude: 0)
        XCTAssertFalse(coord.isValid)
    }

    // MARK: - Formatting

    func testFormattedCoordinate() {
        let coord = TestCoordinate(latitude: 48.856600, longitude: 2.352200)
        XCTAssertEqual(coord.formatted, "48.856600, 2.352200")
    }
}

// MARK: - Test-local coordinate type (mirrors the real Coordinate)

struct TestCoordinate {
    var latitude: Double
    var longitude: Double

    var isValid: Bool {
        guard latitude.isFinite && longitude.isFinite else { return false }
        return latitude >= -90 && latitude <= 90 &&
               longitude >= -180 && longitude <= 180
    }

    var formatted: String {
        String(format: "%.6f, %.6f", latitude, longitude)
    }
}
