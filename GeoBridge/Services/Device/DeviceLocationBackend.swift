import Foundation

enum PreparationStatus: Sendable {
    case ready
    case needsTrust
    case needsDeveloperMode
    case needsDiskImage
    case needsTunnel
    case failed(String)
}

protocol DeviceLocationBackend: Sendable {
    var name: String { get }
    func listDevices() async throws -> [IOSDevice]
    func prepareDevice(_ device: IOSDevice) async throws -> PreparationStatus
    func setLocation(device: IOSDevice, latitude: Double, longitude: Double) async throws
    func clearLocation(device: IOSDevice) async throws
}
