import Foundation

struct IOSDevice: Identifiable, Hashable, Sendable {
    let id: String          // UDID
    let name: String
    let iOSVersion: String
    let connectionType: ConnectionType
    var isTrusted: Bool

    var iOSMajorVersion: Int {
        Int(iOSVersion.split(separator: ".").first ?? "0") ?? 0
    }

    var displayName: String { name.isEmpty ? "iPhone" : name }

    enum ConnectionType: String, Sendable {
        case usb = "USB"
        case wifi = "Network"
        case unknown = "Unknown"
    }

    static let mock = IOSDevice(
        id: "00008120-001A2B3C4D5E6F78",
        name: "iPhone 15 (Demo)",
        iOSVersion: "17.4",
        connectionType: .usb,
        isTrusted: true
    )
}
