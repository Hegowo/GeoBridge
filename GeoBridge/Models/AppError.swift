import Foundation

enum AppError: LocalizedError, Equatable, Sendable {
    case noDevice
    case deviceNotTrusted
    case developerModeRequired
    case dependencyMissing(String)
    case commandFailed(String)
    case devicePreparationFailed(String)
    case locationSetFailed(String)
    case locationClearFailed(String)
    case parseError(String)
    case networkError(String)
    case timeout
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .noDevice:
            return "No iPhone connected. Connect your device via USB."
        case .deviceNotTrusted:
            return "iPhone not trusted. Unlock your iPhone and tap \"Trust This Computer\"."
        case .developerModeRequired:
            return "Developer Mode is off. On your iPhone: Settings → Privacy & Security → Developer Mode → Enable → Reboot."
        case .dependencyMissing(let tool):
            return "\(tool) is not installed. Open the Setup Guide to install dependencies."
        case .commandFailed(let detail):
            return "Command failed: \(detail)"
        case .devicePreparationFailed(let detail):
            return "Device preparation failed: \(detail)"
        case .locationSetFailed(let detail):
            return "Failed to set location: \(detail)"
        case .locationClearFailed(let detail):
            return "Failed to clear location: \(detail)"
        case .parseError(let detail):
            return "Could not parse response: \(detail)"
        case .networkError(let detail):
            return "Network error: \(detail)"
        case .timeout:
            return "Operation timed out. Check device connection."
        case .unknown(let detail):
            return "Unexpected error: \(detail)"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .noDevice:
            return "Connect via USB and ensure the cable supports data transfer."
        case .deviceNotTrusted:
            return "Unlock your iPhone and select \"Trust\" in the dialog."
        case .developerModeRequired:
            return "Settings → Privacy & Security → Developer Mode → Enable, then reboot."
        case .dependencyMissing:
            return "Open the Setup Guide (⌘,) for installation instructions."
        case .timeout:
            return "Replug the USB cable and try again."
        default:
            return nil
        }
    }

    static func == (lhs: AppError, rhs: AppError) -> Bool {
        lhs.errorDescription == rhs.errorDescription
    }
}
