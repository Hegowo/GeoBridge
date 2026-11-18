import Foundation

/// Fallback backend using libimobiledevice tools.
/// Supports iOS versions where idevicesetlocation works.
final class LibimobiledeviceBackend: DeviceLocationBackend, @unchecked Sendable {
    let name = "libimobiledevice"

    private let runner = CommandRunner.shared

    func listDevices() async throws -> [IOSDevice] {
        guard let ideviceIdPath = await runner.findExecutable("idevice_id") else {
            throw AppError.dependencyMissing("idevice_id (libimobiledevice)")
        }

        // Scan USB (-l) and Wi-Fi network (-n) devices in parallel.
        async let usbResult  = runner.run(executablePath: ideviceIdPath, arguments: ["-l"], timeout: 10)
        async let wifiResult = runner.run(executablePath: ideviceIdPath, arguments: ["-n"], timeout: 10)

        let (usb, wifi) = try await (usbResult, wifiResult)

        func parseUDIDs(_ output: String) -> [String] {
            output.split(separator: "\n")
                  .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                  .filter { !$0.isEmpty }
        }

        let usbUDIDs  = usb.succeeded  ? parseUDIDs(usb.stdout)  : []
        let wifiUDIDs = wifi.succeeded ? parseUDIDs(wifi.stdout) : []

        // USB takes priority: if a device appears in both, keep it as USB.
        var seen = Set(usbUDIDs)
        let usbDevices  = usbUDIDs.map  { IOSDevice(id: $0, name: "iPhone", iOSVersion: "Unknown", connectionType: .usb,  isTrusted: true) }
        let wifiDevices = wifiUDIDs.compactMap { udid -> IOSDevice? in
            guard seen.insert(udid).inserted else { return nil }
            return IOSDevice(id: udid, name: "iPhone", iOSVersion: "Unknown", connectionType: .wifi, isTrusted: true)
        }

        return usbDevices + wifiDevices
    }

    // These are best-effort synchronous calls; failure returns defaults.
    private func fetchDeviceName(udid: String) -> String { "iPhone" }
    private func fetchiOSVersion(udid: String) -> String { "Unknown" }

    func prepareDevice(_ device: IOSDevice) async throws -> PreparationStatus {
        // libimobiledevice doesn't do developer disk mounting; just verify tool presence
        guard await runner.findExecutable("idevicesetlocation") != nil else {
            throw AppError.dependencyMissing("idevicesetlocation")
        }
        return .ready
    }

    func setLocation(device: IOSDevice, latitude: Double, longitude: Double) async throws {
        guard let path = await runner.findExecutable("idevicesetlocation") else {
            throw AppError.dependencyMissing("idevicesetlocation")
        }
        // idevicesetlocation -u UDID -- LATITUDE LONGITUDE
        let result = try await runner.run(
            executablePath: path,
            arguments: ["-u", device.id, "--", String(latitude), String(longitude)],
            timeout: 15
        )
        if !result.succeeded {
            throw AppError.locationSetFailed(result.stderr.isEmpty ? result.stdout : result.stderr)
        }
    }

    func clearLocation(device: IOSDevice) async throws {
        guard let path = await runner.findExecutable("idevicesetlocation") else {
            throw AppError.dependencyMissing("idevicesetlocation")
        }
        // idevicesetlocation -u UDID reset
        let result = try await runner.run(
            executablePath: path,
            arguments: ["-u", device.id, "reset"],
            timeout: 15
        )
        if !result.succeeded {
            throw AppError.locationClearFailed(result.stderr)
        }
    }
}
