import Foundation
import MapKit
import CoreLocation

enum TransportMode: String, CaseIterable, Identifiable {
    case walking = "Walking"
    case driving = "Driving"
    case transit = "Transit"

    var id: String { rawValue }

    var mkTransportType: MKDirectionsTransportType {
        switch self {
        case .walking: return .walking
        case .driving: return .automobile
        case .transit: return .transit
        }
    }

    var systemImage: String {
        switch self {
        case .walking: return "figure.walk"
        case .driving: return "car.fill"
        case .transit: return "tram.fill"
        }
    }

    // Typical speed used only as a fallback if MKDirections doesn't provide travel time.
    var defaultMetersPerSecond: Double {
        switch self {
        case .walking: return 1.4
        case .driving: return 13.9
        case .transit: return 8.3
        }
    }
}

struct PlannedRoute {
    let transportMode: TransportMode
    let totalDistance: Double       // metres
    let expectedTravelTime: Double  // seconds
    let polylineCoordinates: [CLLocationCoordinate2D]
    let steps: [RouteStep]

    var formattedDistance: String {
        totalDistance < 1000
            ? String(format: "%.0f m", totalDistance)
            : String(format: "%.1f km", totalDistance / 1000)
    }

    var formattedDuration: String {
        let mins = Int(expectedTravelTime / 60)
        guard mins >= 60 else { return "\(mins) min" }
        let h = mins / 60; let m = mins % 60
        return m > 0 ? "\(h)h \(m)min" : "\(h)h"
    }
}

struct RouteStep {
    let instructions: String
    let distance: Double

    var formattedDistance: String {
        distance < 1000
            ? String(format: "%.0f m", distance)
            : String(format: "%.1f km", distance / 1000)
    }
}
