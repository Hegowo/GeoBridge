import CoreLocation

struct Coordinate: Codable, Hashable, Sendable {
    var latitude: Double
    var longitude: Double

    var isValid: Bool {
        latitude >= -90 && latitude <= 90 &&
        longitude >= -180 && longitude <= 180
    }

    var clCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var formatted: String {
        String(format: "%.6f, %.6f", latitude, longitude)
    }

    static let paris = Coordinate(latitude: 48.8566, longitude: 2.3522)
}
