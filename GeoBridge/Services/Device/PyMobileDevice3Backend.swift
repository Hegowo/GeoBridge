import Foundation

actor PyMobileDevice3Backend: DeviceLocationBackend {
    let name = "pymobiledevice3"

    private var cachedExecutablePath: String?

    private var helperProcess:  Process?
    private var helperStdin:    FileHandle?
    private var helperReady:    Bool = false
    private let helperStartupTimeout: TimeInterval = 30

    private var activeSimulationProcess: Process?
    private var locationSessionEstablished = false

    private func pmd3Path() async throws -> String {
        if let cached = cachedExecutablePath { return cached }
        guard let path = await pmd3Candidates().first else {
            throw AppError.dependencyMissing("pymobiledevice3")
        }
        cachedExecutablePath = path
        return path
    }

    private func pmd3Candidates() async -> [String] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        var paths = [
            cachedExecutablePath,
            "\(home)/.local/bin/pymobiledevice3",
            "\(home)/.pipx/shims/pymobiledevice3",
            "/opt/homebrew/bin/pymobiledevice3",
            "/usr/local/bin/pymobiledevice3",
        ].compactMap { $0 }
        if let found = await CommandRunner.shared.findExecutable("pymobiledevice3") {
            paths.append(found)
        }
        var seen = Set<String>()
        return paths.filter { path in
            guard FileManager.default.isExecutableFile(atPath: path) else { return false }
            let key = pythonPath(for: path) ?? URL(fileURLWithPath: path).resolvingSymlinksInPath().path
            return seen.insert(key).inserted
        }
    }

    func listDevices() async throws -> [IOSDevice] {
        let path = try await pmd3Path()
        let result = try await CommandRunner.shared.run(
            executablePath: path,
            arguments: ["usbmux", "list"],
            timeout: 10
        )
        let raw = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty, let data = raw.data(using: .utf8) else { return [] }
        return (try? parseDeviceList(from: data)) ?? []
    }

    private func parseDeviceList(from data: Data) throws -> [IOSDevice] {
        if let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            return array.compactMap(deviceFromDict)
        }
        if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            return [deviceFromDict(obj)].compactMap { $0 }
        }
        return []
    }

    private func deviceFromDict(_ d: [String: Any]) -> IOSDevice? {
        guard let udid = d["Identifier"] as? String
                      ?? d["UniqueDeviceID"] as? String else { return nil }
        return IOSDevice(
            id: udid,
            name: d["DeviceName"] as? String ?? "iPhone",
            iOSVersion: d["ProductVersion"] as? String ?? "Unknown",
            connectionType: (d["ConnectionType"] as? String)
                .flatMap { IOSDevice.ConnectionType(rawValue: $0) } ?? .usb,
            isTrusted: true
        )
    }

    func prepareDevice(_ device: IOSDevice) async throws -> PreparationStatus {
        let path = try await pmd3Path()

        if device.iOSMajorVersion >= 17 {
            let probeResult = try await CommandRunner.shared.run(
                executablePath: path,
                arguments: ["developer", "dvt", "simulate-location", "clear",
                            "--udid", device.id],
                timeout: 15
            )
            let probeOut = (probeResult.stdout + probeResult.stderr).lowercased()

            if probeOut.contains("unable to connect to tunneld") ||
               probeOut.contains("error unable to connect") ||
               probeOut.contains("no tunnel available") ||
               probeOut.contains("failed to connect to tunneld") {
                return .needsTunnel
            }
            if probeOut.contains("developer mode") { return .needsDeveloperMode }
            if probeOut.contains("trust") || probeOut.contains("pair") { return .needsTrust }
            return .ready
        } else {
            let result = try await CommandRunner.shared.run(
                executablePath: path,
                arguments: ["mounter", "auto-mount"],
                timeout: 60
            )
            if result.succeeded { return .ready }
            let err = (result.stdout + result.stderr).lowercased()
            if err.contains("developer mode") { return .needsDeveloperMode }
            if err.contains("trust") || err.contains("pair") { return .needsTrust }
            if err.contains("already mounted") { return .ready }
            return .failed(result.stderr.isEmpty ? result.stdout : result.stderr)
        }
    }

    func setLocation(device: IOSDevice, latitude: Double, longitude: Double) async throws {
        let coordLine = "\(latitude),\(longitude)\n"
        let coordData = coordLine.data(using: .utf8)!

        if helperReady,
           let proc = helperProcess, proc.isRunning,
           let stdin = helperStdin {
            try? stdin.write(contentsOf: coordData)
            return
        }

        helperReady = false
        do {
            try await startHelper(device: device)
            try? helperStdin?.write(contentsOf: coordData)
        } catch let helperError {
            do {
                try await setLocationViaRestart(device: device, latitude: latitude, longitude: longitude)
            } catch {
                throw AppError.locationSetFailed(
                    "\(helperError.localizedDescription)\n" +
                    "\(error.localizedDescription)\n" +
                    "Check the iPhone is unlocked and tunneld is running: sudo pymobiledevice3 remote tunneld"
                )
            }
        }
    }

    func clearLocation(device: IOSDevice) async throws {
        stopHelper()
        activeSimulationProcess?.terminate()
        activeSimulationProcess = nil
        locationSessionEstablished = false

        try? await Task.sleep(for: .milliseconds(300))

        let path = try await pmd3Path()
        let result = try await CommandRunner.shared.run(
            executablePath: path,
            arguments: ["developer", "dvt", "simulate-location", "clear",
                        "--udid", device.id],
            timeout: 15
        )
        let combined = (result.stdout + result.stderr).lowercased()
        if combined.contains("unable to connect to tunneld") ||
           combined.contains("error unable to connect") ||
           combined.contains("no tunnel available") ||
           combined.contains("failed to connect to tunneld") {
            throw AppError.locationClearFailed(
                "Tunnel not running. Start it with: sudo ~/.local/bin/pymobiledevice3 remote tunneld"
            )
        }
    }

    private func startHelper(device: IOSDevice) async throws {
        stopHelper()

        guard let scriptPath = helperScriptPath() else {
            throw BackendError.helperScriptNotFound
        }

        let candidates = await pmd3Candidates()
        guard !candidates.isEmpty else { throw AppError.dependencyMissing("pymobiledevice3") }

        var failures: [String] = []
        for (index, pmd3) in candidates.enumerated() {
            guard let pythonPath = pythonPath(for: pmd3) else { continue }
            do {
                try await launchHelper(
                    pythonPath: pythonPath,
                    scriptPath: scriptPath,
                    device: device,
                    waitForTunnel: index == 0 && device.iOSMajorVersion >= 17
                )
                cachedExecutablePath = pmd3
                return
            } catch {
                failures.append("\(pmd3): \(error.localizedDescription)")
            }
        }
        throw BackendError.helperStartupFailed(
            failures.isEmpty ? "no usable Python interpreter" : failures.joined(separator: "\n")
        )
    }

    private func launchHelper(
        pythonPath: String, scriptPath: String, device: IOSDevice, waitForTunnel: Bool
    ) async throws {
        let stdinPipe  = Pipe()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        let output = HelperOutput()

        stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
            output.appendStdout(handle.availableData)
        }
        stderrPipe.fileHandleForReading.readabilityHandler = { handle in
            output.appendStderr(handle.availableData)
        }

        var arguments = [scriptPath, device.id]
        if !waitForTunnel { arguments.append("--no-tunnel-wait") }

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: pythonPath)
        proc.arguments = arguments
        proc.standardInput  = stdinPipe
        proc.standardOutput = stdoutPipe
        proc.standardError  = stderrPipe
        proc.environment = ProcessInfo.processInfo.environment

        try proc.run()
        helperProcess = proc

        let deadline = Date().addingTimeInterval(helperStartupTimeout)
        while Date() < deadline && proc.isRunning {
            if output.isReady {
                helperStdin  = stdinPipe.fileHandleForWriting
                helperReady  = true
                locationSessionEstablished = true
                return
            }
            try await Task.sleep(for: .milliseconds(150))
        }

        if proc.isRunning { proc.terminate() }
        proc.waitUntilExit()
        stdoutPipe.fileHandleForReading.readabilityHandler = nil
        stderrPipe.fileHandleForReading.readabilityHandler = nil
        output.appendStderr(stderrPipe.fileHandleForReading.readDataToEndOfFile())
        helperProcess = nil

        let errStr = output.lastErrorLine
        throw BackendError.helperAttemptFailed(errStr.isEmpty ? "timed out waiting for READY" : errStr)
    }

    private func stopHelper() {
        if let stdin = helperStdin {
            try? stdin.write(contentsOf: "STOP\n".data(using: .utf8)!)
        }
        helperProcess?.terminate()
        helperProcess = nil
        helperStdin   = nil
        helperReady   = false
    }

    private func setLocationViaRestart(
        device: IOSDevice, latitude: Double, longitude: Double
    ) async throws {
        let path   = try await pmd3Path()
        let latStr = String(latitude)
        let lonStr = String(longitude)

        let previousProcess = activeSimulationProcess

        let newProc = try CommandRunner.shared.launchDetached(
            executablePath: path,
            arguments: ["developer", "dvt", "simulate-location", "set",
                        "--udid", device.id, "--", latStr, lonStr]
        )

        let waitMs = locationSessionEstablished ? 500 : 4000
        try await Task.sleep(for: .milliseconds(waitMs))

        guard newProc.isRunning else {
            locationSessionEstablished = false
            activeSimulationProcess = nil
            throw BackendError.simulationExited(lastLine(ofOutputOf: newProc))
        }

        previousProcess?.terminate()
        activeSimulationProcess = newProc
        locationSessionEstablished = true
    }

    private func lastLine(ofOutputOf process: Process) -> String {
        let pipes = [process.standardError, process.standardOutput].compactMap { $0 as? Pipe }
        let text = pipes
            .map { String(data: $0.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? "" }
            .joined(separator: "\n")
        return HelperOutput.meaningfulLastLine(of: text)
    }

    private func helperScriptPath() -> String? {
        let execPath = ProcessInfo.processInfo.arguments.first ?? ""
        let execDir  = URL(fileURLWithPath: execPath).deletingLastPathComponent()
        let candidates = [
            execDir.appendingPathComponent("../Resources/location_helper.py")
                   .standardized.path,
            execDir.appendingPathComponent("location_helper.py").path,
        ]
        return candidates.first { FileManager.default.fileExists(atPath: $0) }
    }

    private nonisolated func pythonPath(for pmd3: String) -> String? {
        guard let content = try? String(contentsOfFile: pmd3, encoding: .utf8),
              let firstLine = content.split(separator: "\n", maxSplits: 1).first,
              firstLine.hasPrefix("#!") else { return nil }
        let python = String(firstLine.dropFirst(2)).trimmingCharacters(in: .whitespaces)
        return FileManager.default.isExecutableFile(atPath: python) ? python : nil
    }
}

private enum BackendError: LocalizedError {
    case helperScriptNotFound
    case helperStartupFailed(String)
    case helperAttemptFailed(String)
    case simulationExited(String)

    var errorDescription: String? {
        switch self {
        case .helperScriptNotFound:
            return "location_helper.py not found in app bundle"
        case .helperStartupFailed(let msg):
            return "Location helper failed to start: \(msg)"
        case .helperAttemptFailed(let msg):
            return msg
        case .simulationExited(let msg):
            return msg.isEmpty ? "simulate-location exited immediately" : "simulate-location exited: \(msg)"
        }
    }
}

private final class HelperOutput: @unchecked Sendable {
    private let lock = NSLock()
    private var stdoutBytes = Data()
    private var stderrBytes = Data()

    func appendStdout(_ data: Data) { lock.withLock { stdoutBytes.append(data) } }
    func appendStderr(_ data: Data) { lock.withLock { stderrBytes.append(data) } }

    var isReady: Bool {
        lock.withLock { String(data: stdoutBytes, encoding: .utf8)?.contains("READY") ?? false }
    }

    var lastErrorLine: String {
        Self.meaningfulLastLine(of: lock.withLock { String(data: stderrBytes, encoding: .utf8) ?? "" })
    }

    static func meaningfulLastLine(of text: String) -> String {
        let noise = ["RuntimeWarning", "tracemalloc", "Press Ctrl+C", "coroutine '"]
        return text
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { line in !line.isEmpty && !noise.contains { line.contains($0) } }
            .last ?? ""
    }
}
