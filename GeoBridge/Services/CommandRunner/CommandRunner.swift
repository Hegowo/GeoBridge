import Foundation

struct CommandResult: Sendable {
    let exitCode: Int32
    let stdout: String
    let stderr: String
    var succeeded: Bool { exitCode == 0 }
}

enum CommandError: LocalizedError, Sendable {
    case notFound(String)
    case timedOut(String)
    case systemError(String)

    var errorDescription: String? {
        switch self {
        case .notFound(let p): return "Executable not found: \(p)"
        case .timedOut(let cmd): return "Command timed out: \(cmd)"
        case .systemError(let msg): return "System error: \(msg)"
        }
    }
}

// Thread-safe output buffer used inside closures that may run on any thread.
private final class OutputCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var stdoutBytes = Data()
    private var stderrBytes = Data()

    func appendStdout(_ data: Data) { lock.withLock { stdoutBytes.append(data) } }
    func appendStderr(_ data: Data) { lock.withLock { stderrBytes.append(data) } }

    var stdout: String { lock.withLock { String(data: stdoutBytes, encoding: .utf8) ?? "" } }
    var stderr: String { lock.withLock { String(data: stderrBytes, encoding: .utf8) ?? "" } }
}

actor CommandRunner {
    static let shared = CommandRunner()
    private init() {}

    // Never build shell commands with string interpolation.
    // Always pass executable path and arguments as separate values.
    func run(
        executablePath: String,
        arguments: [String],
        environment: [String: String]? = nil,
        timeout: TimeInterval = 30,
        logHandler: (@Sendable (String, LogEntry.Level) -> Void)? = nil
    ) async throws -> CommandResult {
        guard FileManager.default.isExecutableFile(atPath: executablePath) else {
            throw CommandError.notFound(executablePath)
        }

        return try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executablePath)
            process.arguments = arguments
            process.environment = mergedEnv(extra: environment)

            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe

            let collector = OutputCollector()

            stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                guard !data.isEmpty else { return }
                collector.appendStdout(data)
                if let text = String(data: data, encoding: .utf8), !text.isEmpty {
                    logHandler?(text.trimmingCharacters(in: .newlines), .output)
                }
            }

            stderrPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                guard !data.isEmpty else { return }
                collector.appendStderr(data)
                if let text = String(data: data, encoding: .utf8), !text.isEmpty {
                    logHandler?(text.trimmingCharacters(in: .newlines), .warning)
                }
            }

            // Lock-protected flag: only the first caller (timeout vs. natural exit)
            // resumes the continuation. DispatchSemaphore can't be used here because
            // libdispatch requires balanced signal/wait at dealloc time.
            final class ResumeOnce: @unchecked Sendable {
                private let lock = NSLock()
                private var fired = false
                func tryFire() -> Bool {
                    lock.withLock {
                        guard !fired else { return false }
                        fired = true
                        return true
                    }
                }
            }
            let gate = ResumeOnce()

            let timeoutItem = DispatchWorkItem {
                if process.isRunning { process.terminate() }
                guard gate.tryFire() else { return }
                continuation.resume(throwing: CommandError.timedOut(executablePath))
            }
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout, execute: timeoutItem)

            process.terminationHandler = { proc in
                timeoutItem.cancel()
                stdoutPipe.fileHandleForReading.readabilityHandler = nil
                stderrPipe.fileHandleForReading.readabilityHandler = nil

                let remaining = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                let remainingErr = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                collector.appendStdout(remaining)
                collector.appendStderr(remainingErr)

                guard gate.tryFire() else { return }
                continuation.resume(returning: CommandResult(
                    exitCode: proc.terminationStatus,
                    stdout: collector.stdout,
                    stderr: collector.stderr
                ))
            }

            do {
                try process.run()
            } catch {
                timeoutItem.cancel()
                guard gate.tryFire() else { return }
                continuation.resume(throwing: CommandError.systemError(error.localizedDescription))
            }
        }
    }

    // Launches a process that should remain running (e.g. DVT simulate-location).
    // The returned Process is NOT actor-isolated; the caller stores and terminates it.
    nonisolated func launchDetached(
        executablePath: String,
        arguments: [String],
        environment: [String: String]? = nil
    ) throws -> Process {
        guard FileManager.default.isExecutableFile(atPath: executablePath) else {
            throw CommandError.notFound(executablePath)
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments
        process.environment = mergedEnv(extra: environment)
        // Silence DVT output; the long-lived process just needs to keep running.
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        try process.run()
        return process
    }

    func findExecutable(_ name: String) async -> String? {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let candidates = [
            "/usr/local/bin/\(name)",
            "/opt/homebrew/bin/\(name)",
            "/opt/homebrew/sbin/\(name)",
            "/usr/bin/\(name)",
            "\(home)/.local/bin/\(name)",   // pipx default install location
            "\(home)/.pipx/shims/\(name)"   // older pipx versions
        ]
        for path in candidates where FileManager.default.isExecutableFile(atPath: path) {
            return path
        }
        if let result = try? await run(
            executablePath: "/usr/bin/which",
            arguments: [name],
            timeout: 5
        ), result.succeeded {
            let path = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            if !path.isEmpty { return path }
        }
        return nil
    }

    private nonisolated func mergedEnv(extra: [String: String]?) -> [String: String] {
        var env = ProcessInfo.processInfo.environment
        extra?.forEach { env[$0.key] = $0.value }
        return env
    }
}
