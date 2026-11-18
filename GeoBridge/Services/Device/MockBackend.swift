import Foundation

/// Mock backend for UI development and testing.
/// Does not communicate with any real device.
final class MockBackend: DeviceLocationBackend, @unchecked Sendable {
    let name = "Mock (Demo)"

    private(set) var simulatedCoordinate: Coordinate?
    var simulateConnectionDelay = true

    private let mockDevices: [IOSDevice] = [
        IOSDevice(
            id: "00008120-001A2B3C4D5E6F78",
            name: "iPhone 15 (Demo)",
            iOSVersion: "17.4",
            connectionType: .usb,
            isTrusted: true
        ),
        IOSDevice(
            id: "00008110-000A1B2C3D4E5F60",
            name: "iPhone 14 (Demo)",
            iOSVersion: "16.7",
            connectionType: .usb,
            isTrusted: true
        )
    ]

    func listDevices() async throws -> [IOSDevice] {
        if simulateConnectionDelay {
            try await Task.sleep(for: .milliseconds(500))
        }
        return mockDevices
    }

    func prepareDevice(_ device: IOSDevice) async throws -> PreparationStatus {
        if simulateConnectionDelay {
            try await Task.sleep(for: .seconds(1))
        }
        return .ready
    }

    func setLocation(device: IOSDevice, latitude: Double, longitude: Double) async throws {
        if simulateConnectionDelay {
            try await Task.sleep(for: .milliseconds(800))
        }
        simulatedCoordinate = Coordinate(latitude: latitude, longitude: longitude)
    }

    func clearLocation(device: IOSDevice) async throws {
        if simulateConnectionDelay {
            try await Task.sleep(for: .milliseconds(500))
        }
        simulatedCoordinate = nil
    }
}
