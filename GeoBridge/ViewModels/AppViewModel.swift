import SwiftUI
import Combine
import CoreLocation

// MARK: - Supporting types

enum ConnectionScanMode: String, CaseIterable, Identifiable {
    case usbOnly    = "USB"
    case wifiOnly   = "Wi-Fi"
    case usbAndWifi = "Both"
    var id: String { rawValue }
}

enum TunnelState: Sendable {
    case unknown
    case notRunning
    case starting
    case running(pid: Int32)
    case failed(String)

    var isRunning:  Bool { if case .running  = self { return true }; return false }
    var isStarting: Bool { if case .starting = self { return true }; return false }

    var label: String {
        switch self {
        case .unknown:        return "Checking…"
        case .notRunning:     return "Not running"
        case .starting:       return "Starting…"
        case .running(let p): return "Running (PID \(p))"
        case .failed(let m):  return m.isEmpty ? "Failed" : m
        }
    }

    var colorName: String {
        switch self {
        case .running:  return "green"
        case .starting: return "orange"
        case .failed:   return "red"
        default:        return "secondary"
        }
    }
}

// MARK: - ViewModel

@MainActor
final class AppViewModel: ObservableObject {
    // MARK: - Published state

    @Published var deviceState: DeviceState = .noDevice
    @Published var devices: [IOSDevice] = []
    @Published var selectedDevice: IOSDevice?
    @Published var selectedCoordinate: Coordinate?
    @Published var logs: [LogEntry] = []
    @Published var favorites: [NamedLocation] = []
    @Published var recentLocations: [NamedLocation] = []
    @Published var dependencyStatus: DependencyStatus?
    @Published var isMockMode: Bool = false
    @Published var mapRegionCenter: Coordinate = .paris
    @Published var tunnelState: TunnelState = .unknown
    @Published var connectionScanMode: ConnectionScanMode = .usbAndWifi {
        didSet {
            // Clear per-device preferences when mode changes — let user re-choose.
            deviceConnectionPreferences.removeAll()
            dualConnectionPrompt = nil
            Task { await refreshDevices() }
        }
    }
    /// Non-nil when the same UDID appears on both USB and Wi-Fi in "Both" mode.
    @Published var dualConnectionPrompt: (usbDevice: IOSDevice, wifiDevice: IOSDevice)? = nil
    /// Route polyline for the map overlay (set by RouteViewModel).
    @Published var routePolyline: [CLLocationCoordinate2D]? = nil

    /// Persisted per-UDID connection type preference chosen by the user.
    private var deviceConnectionPreferences: [String: IOSDevice.ConnectionType] = [:]

    private var backend: any DeviceLocationBackend
    private let dynamicBackend = DynamicDeviceBackend()
    private let mockBackend = MockBackend()
    private let persistence = PersistenceService.shared
    private var autoRefreshTask: Task<Void, Never>?

    // MARK: - Init

    init() {
        backend = DynamicDeviceBackend()
    }

    // MARK: - Lifecycle

    func initialize() async {
        log("GeoBridge started", level: .info)
        async let deps    = DependencyChecker.shared.check()
        async let favs    = persistence.loadFavorites()
        async let recents = persistence.loadRecents()

        let (status, loadedFavs, loadedRecents) = await (deps, favs, recents)
        dependencyStatus = status
        favorites        = loadedFavs
        recentLocations  = loadedRecents

        if !status.hasAnyBackend {
            log("No device backend found. Install pymobiledevice3 or libimobiledevice.", level: .warning)
        } else {
            log("Backend: \(status.preferredBackend == .pymobiledevice3 ? "pymobiledevice3" : "libimobiledevice")", level: .info)
            await refreshDevices()
        }

        await checkTunnelStatus()
        startAutoRefresh()
    }

    func handleAppTermination() async {
        autoRefreshTask?.cancel()
        if case .simulationActive(let device, _) = deviceState {
            log("App terminating — clearing simulated location…", level: .info)
            try? await backend.clearLocation(device: device)
        }
        await persistence.saveFavorites(favorites)
        await persistence.saveRecents(recentLocations)
    }

    // MARK: - Auto-refresh

    private func startAutoRefresh() {
        autoRefreshTask?.cancel()
        autoRefreshTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(5))
                guard !Task.isCancelled else { break }
                await self?.autoRefreshTick()
            }
        }
    }

    private func autoRefreshTick() async {
        // Skip if an operation is in progress
        switch deviceState {
        case .connecting, .applyingLocation, .preparingServices: return
        default: break
        }

        guard let newDevices = try? await backend.listDevices() else { return }

        // Re-check after the await — state may have changed while waiting
        switch deviceState {
        case .connecting, .applyingLocation, .preparingServices: return
        default: break
        }

        let filtered = applyConnectionFilter(newDevices)
        let prevIDs  = Set(devices.map(\.id))
        let newIDs   = Set(filtered.map(\.id))

        if prevIDs != newIDs {
            log("Device change detected — refreshing…", level: .info)
            await refreshDevices()
        }

        await checkTunnelStatus()
    }

    // MARK: - Connection filter

    private func applyConnectionFilter(_ list: [IOSDevice]) -> [IOSDevice] {
        let filtered: [IOSDevice]
        switch connectionScanMode {
        case .usbOnly:    filtered = list.filter { $0.connectionType == .usb  }
        case .wifiOnly:   filtered = list.filter { $0.connectionType == .wifi }
        case .usbAndWifi: filtered = list
        }
        return resolveDualConnections(filtered)
    }

    /// When the same UDID appears on both USB and Wi-Fi, apply the stored
    /// preference (if any) or trigger a prompt for the user to choose.
    private func resolveDualConnections(_ list: [IOSDevice]) -> [IOSDevice] {
        var byUDID: [String: [IOSDevice]] = [:]
        for device in list { byUDID[device.id, default: []].append(device) }

        var resolved: [IOSDevice] = []
        var promptNeeded: (IOSDevice, IOSDevice)? = nil

        for (udid, group) in byUDID {
            if group.count == 1 {
                resolved.append(group[0])
                continue
            }
            let usbDevice  = group.first { $0.connectionType == .usb  }
            let wifiDevice = group.first { $0.connectionType == .wifi }

            if let pref = deviceConnectionPreferences[udid] {
                resolved.append(group.first { $0.connectionType == pref } ?? group[0])
            } else if let u = usbDevice, let w = wifiDevice {
                // No preference yet — prompt and temporarily use USB.
                promptNeeded = (u, w)
                resolved.append(u)
            } else {
                resolved.append(group[0])
            }
        }

        if let prompt = promptNeeded, dualConnectionPrompt == nil {
            dualConnectionPrompt = prompt
        }

        return resolved
    }

    /// Called by the UI when the user picks a connection type for a dual-connected device.
    func resolveConnectionChoice(udid: String, use connectionType: IOSDevice.ConnectionType) {
        deviceConnectionPreferences[udid] = connectionType
        dualConnectionPrompt = nil
        Task { await refreshDevices() }
    }

    // MARK: - Mock Mode Toggle

    func enableMockMode() {
        isMockMode = true
        backend = mockBackend
        log("Mock mode enabled — no real device required", level: .info)
        Task { await refreshDevices() }
    }

    func disableMockMode() {
        isMockMode = false
        backend = dynamicBackend
        log("Mock mode disabled", level: .info)
        Task {
            await dynamicBackend.invalidate()
            await refreshDevices()
        }
    }

    // MARK: - Device Discovery

    func refreshDevices() async {
        deviceState = .connecting
        log("Scanning for connected devices…", level: .info)

        do {
            let allDevices = try await backend.listDevices()
            devices = applyConnectionFilter(allDevices)

            if devices.isEmpty {
                deviceState  = .noDevice
                selectedDevice = nil
                log("No devices found.", level: .info)
            } else {
                if selectedDevice == nil || !devices.contains(where: { $0.id == selectedDevice?.id }) {
                    selectedDevice = devices.first
                }
                if let device = selectedDevice {
                    log("Found: \(device.displayName) (\(device.iOSVersion))", level: .success)
                    await prepareDevice(device)
                }
            }
        } catch {
            deviceState = .error(nil, errorFrom(error))
            log(error.localizedDescription, level: .error)
        }
    }

    func selectDevice(_ device: IOSDevice) {
        selectedDevice = device
        Task { await prepareDevice(device) }
    }

    private func prepareDevice(_ device: IOSDevice) async {
        deviceState = .preparingServices(device)
        log("Preparing developer services for \(device.displayName)…", level: .info)

        do {
            let status = try await backend.prepareDevice(device)
            switch status {
            case .ready:
                deviceState = .ready(device)
                log("Device ready", level: .success)
            case .needsTrust:
                deviceState = .notTrusted(device)
                log("Trust required: unlock iPhone and tap \"Trust This Computer\"", level: .warning)
            case .needsDeveloperMode:
                deviceState = .developerModeRequired(device)
                log("Developer Mode off. Settings → Privacy & Security → Developer Mode → Enable → Reboot", level: .warning)
            case .needsDiskImage:
                log("Developer Disk Image not mounted. Attempting mount…", level: .info)
                deviceState = .ready(device)
            case .needsTunnel:
                log("iOS 17+ tunnel required. Click \"Start Tunnel\" in the sidebar.", level: .warning)
                deviceState = .error(device, .devicePreparationFailed(
                    "Tunnel not running. Click \"Start Tunnel\" below, then click Refresh."))
            case .failed(let detail):
                deviceState = .error(device, .devicePreparationFailed(detail))
                log("Preparation failed: \(detail)", level: .error)
            }
        } catch {
            deviceState = .error(device, errorFrom(error))
            log(error.localizedDescription, level: .error)
        }
    }

    // MARK: - Tunnel daemon

    func checkTunnelStatus() async {
        let result = try? await CommandRunner.shared.run(
            executablePath: "/usr/bin/pgrep",
            arguments: ["-f", "pymobiledevice3 remote tunneld"],
            timeout: 5
        )
        if let r = result, r.succeeded,
           let line = r.stdout.split(separator: "\n").first,
           let pid  = Int32(line.trimmingCharacters(in: .whitespacesAndNewlines)) {
            tunnelState = .running(pid: pid)
        } else {
            if case .running = tunnelState {
                log("Tunnel daemon stopped", level: .warning)
            }
            tunnelState = .notRunning
        }
    }

    func startTunnelDaemon() async {
        guard let pmd3 = await CommandRunner.shared.findExecutable("pymobiledevice3") else {
            log("pymobiledevice3 not found — install it first", level: .error)
            tunnelState = .failed("pymobiledevice3 not found")
            return
        }

        tunnelState = .starting
        log("Starting tunnel daemon — macOS will ask for your admin password…", level: .info)

        let result = try? await CommandRunner.shared.run(
            executablePath: "/usr/bin/osascript",
            arguments: [
                "-e", "on run argv",
                "-e", "do shell script (quoted form of item 1 of argv) & \" remote tunneld > /tmp/geobridge-tunneld.log 2>&1 &\" with administrator privileges",
                "-e", "end run",
                pmd3,
            ],
            timeout: 60
        )

        if let r = result, !r.succeeded {
            let msg = r.stderr.lowercased().contains("cancel") ? "Cancelled by user" : r.stderr
            tunnelState = .failed(msg.isEmpty ? "Authentication failed" : msg)
            log("Tunnel start cancelled or failed", level: .warning)
            return
        }

        try? await Task.sleep(for: .seconds(2))
        await checkTunnelStatus()

        if case .running = tunnelState {
            log("Tunnel daemon started", level: .success)
            // Auto-refresh devices now that the tunnel is up
            await refreshDevices()
        } else {
            tunnelState = .failed("Started but not detected — check /tmp/geobridge-tunneld.log")
            log("Tunnel may have failed — check /tmp/geobridge-tunneld.log", level: .warning)
        }
    }

    func stopTunnelDaemon() async {
        log("Stopping tunnel daemon…", level: .info)
        let appleScript = "do shell script \"pkill -f 'pymobiledevice3 remote tunneld'\" with administrator privileges"
        _ = try? await CommandRunner.shared.run(
            executablePath: "/usr/bin/osascript",
            arguments: ["-e", appleScript],
            timeout: 30
        )
        try? await Task.sleep(for: .milliseconds(500))
        await checkTunnelStatus()
    }

    // MARK: - Coordinate Selection

    func setSelectedCoordinate(latitude: Double, longitude: Double) {
        let coord = Coordinate(latitude: latitude, longitude: longitude)
        guard coord.isValid else {
            log("Invalid coordinate: \(coord.formatted)", level: .warning)
            return
        }
        selectedCoordinate = coord
    }

    func clearSelectedCoordinate() {
        selectedCoordinate = nil
    }

    // MARK: - Location Actions

    func changeLocation() async {
        guard let device = readyDevice else { return }
        guard let coord = selectedCoordinate, coord.isValid else {
            log("No valid coordinate selected", level: .warning)
            return
        }

        deviceState = .applyingLocation(device)
        log("Setting location to \(coord.formatted)…", level: .command)

        do {
            try await backend.setLocation(device: device, latitude: coord.latitude, longitude: coord.longitude)
            deviceState = .simulationActive(device, coord)
            log("Location set: \(coord.formatted)", level: .success)
            await addToRecents(name: coord.formatted, coordinate: coord)
        } catch {
            deviceState = .ready(device)
            log(error.localizedDescription, level: .error)
        }
    }

    /// Lightweight setLocation used by RouteViewModel during simulation.
    /// Does not change deviceState to .applyingLocation — keeps the UI stable.
    func setRouteLocation(latitude: Double, longitude: Double) async {
        guard let device = readyDevice else { return }
        let coord = Coordinate(latitude: latitude, longitude: longitude)
        try? await backend.setLocation(device: device, latitude: latitude, longitude: longitude)
        selectedCoordinate = coord
        deviceState = .simulationActive(device, coord)
    }

    func resetLocation() async {
        guard let device = selectedDevice else { return }
        log("Restoring real GPS location…", level: .command)

        do {
            try await backend.clearLocation(device: device)
            deviceState = .ready(device)
            log("Real GPS location restored", level: .success)
        } catch {
            log(error.localizedDescription, level: .error)
        }
    }

    // MARK: - Favorites & Recents

    func addFavorite(name: String, coordinate: Coordinate) {
        guard !favorites.contains(where: { $0.coordinate == coordinate }) else { return }
        favorites.append(NamedLocation(name: name, coordinate: coordinate, isFavorite: true))
        Task { await persistence.saveFavorites(favorites) }
        log("Saved favourite: \(name)", level: .info)
    }

    func removeFavorite(_ location: NamedLocation) {
        favorites.removeAll { $0.id == location.id }
        Task { await persistence.saveFavorites(favorites) }
    }

    private func addToRecents(name: String, coordinate: Coordinate) async {
        let entry = NamedLocation(name: name, coordinate: coordinate, isFavorite: false)
        recentLocations.removeAll { $0.coordinate == coordinate }
        recentLocations.insert(entry, at: 0)
        recentLocations = Array(recentLocations.prefix(20))
        await persistence.saveRecents(recentLocations)
    }

    func selectLocation(_ location: NamedLocation) {
        selectedCoordinate = location.coordinate
        mapRegionCenter    = location.coordinate
    }

    // MARK: - Logs

    func log(_ message: String, level: LogEntry.Level = .info) {
        let entry = LogEntry(level: level, message: message)
        logs.append(entry)
        if logs.count > 500 { logs.removeFirst(100) }
    }

    func clearLogs() { logs.removeAll() }

    func exportLogs() -> String {
        logs.map { "[\($0.formattedTime)] [\($0.level.rawValue)] \($0.message)" }
            .joined(separator: "\n")
    }

    func copyCoordinates() {
        guard let coord = selectedCoordinate else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(coord.formatted, forType: .string)
        log("Coordinates copied: \(coord.formatted)", level: .info)
    }

    // MARK: - Helpers

    var readyDevice: IOSDevice? {
        switch deviceState {
        case .ready(let d), .simulationActive(let d, _): return d
        default: return nil
        }
    }

    var canChangeLocation: Bool {
        guard let coord = selectedCoordinate, coord.isValid else { return false }
        return deviceState.isReady
    }

    var canResetLocation: Bool { deviceState.isSimulating }

    private func errorFrom(_ error: Error) -> AppError {
        (error as? AppError) ?? .unknown(error.localizedDescription)
    }
}
