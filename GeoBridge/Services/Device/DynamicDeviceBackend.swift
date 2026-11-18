import Foundation

/// Selects the best available backend at runtime.
/// Order: pymobiledevice3 → libimobiledevice → error.
actor DynamicDeviceBackend: DeviceLocationBackend {
    let name = "Dynamic (auto)"
    private var resolvedBackend: (any DeviceLocationBackend)?

    func invalidate() { resolvedBackend = nil }

    private func backend() async throws -> any DeviceLocationBackend {
        if let b = resolvedBackend { return b }
        let status = await DependencyChecker.shared.check()
        let b: any DeviceLocationBackend
        switch status.preferredBackend {
        case .pymobiledevice3:
            b = PyMobileDevice3Backend()
        case .libimobiledevice:
            b = LibimobiledeviceBackend()
        case .none:
            throw AppError.dependencyMissing(
                "No supported tool found. Install pymobiledevice3 or libimobiledevice."
            )
        }
        resolvedBackend = b
        return b
    }

    func listDevices() async throws -> [IOSDevice] {
        try await backend().listDevices()
    }

    func prepareDevice(_ device: IOSDevice) async throws -> PreparationStatus {
        try await backend().prepareDevice(device)
    }

    func setLocation(device: IOSDevice, latitude: Double, longitude: Double) async throws {
        try await backend().setLocation(device: device, latitude: latitude, longitude: longitude)
    }

    func clearLocation(device: IOSDevice) async throws {
        try await backend().clearLocation(device: device)
    }
}
