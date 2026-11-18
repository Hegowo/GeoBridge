import Foundation

enum DeviceState: Equatable, Sendable {
    case noDevice
    case connecting
    case notTrusted(IOSDevice)
    case developerModeRequired(IOSDevice)
    case preparingServices(IOSDevice)
    case ready(IOSDevice)
    case applyingLocation(IOSDevice)
    case simulationActive(IOSDevice, Coordinate)
    case error(IOSDevice?, AppError)

    var device: IOSDevice? {
        switch self {
        case .noDevice, .connecting: return nil
        case .notTrusted(let d), .developerModeRequired(let d),
             .preparingServices(let d), .ready(let d),
             .applyingLocation(let d), .simulationActive(let d, _): return d
        case .error(let d, _): return d
        }
    }

    var isReady: Bool {
        if case .ready = self { return true }
        if case .simulationActive = self { return true }
        return false
    }

    var isSimulating: Bool {
        if case .simulationActive = self { return true }
        return false
    }

    var statusLabel: String {
        switch self {
        case .noDevice: return "No Device"
        case .connecting: return "Connecting…"
        case .notTrusted: return "Trust Required"
        case .developerModeRequired: return "Developer Mode Off"
        case .preparingServices: return "Preparing Services…"
        case .ready: return "Ready"
        case .applyingLocation: return "Applying Location…"
        case .simulationActive: return "Simulation Active"
        case .error: return "Error"
        }
    }

    var statusColor: String {
        switch self {
        case .noDevice, .connecting: return "gray"
        case .notTrusted, .developerModeRequired: return "orange"
        case .preparingServices, .applyingLocation: return "blue"
        case .ready, .simulationActive: return "green"
        case .error: return "red"
        }
    }
}
