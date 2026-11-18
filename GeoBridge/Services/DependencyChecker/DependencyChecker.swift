import Foundation

enum ToolStatus: Equatable, Sendable {
    case available(path: String)
    case notFound
    case error(String)

    var isAvailable: Bool {
        if case .available = self { return true }
        return false
    }

    var path: String? {
        if case .available(let p) = self { return p }
        return nil
    }
}

struct DependencyStatus: Sendable {
    var pymobiledevice3: ToolStatus = .notFound
    var idevicesetlocation: ToolStatus = .notFound
    var ideviceId: ToolStatus = .notFound
    var xcodeCommandLineTools: ToolStatus = .notFound
    var python3: ToolStatus = .notFound

    var hasPymobiledevice3: Bool { pymobiledevice3.isAvailable }
    var hasLibimobiledevice: Bool { idevicesetlocation.isAvailable }
    var hasAnyBackend: Bool { hasPymobiledevice3 || hasLibimobiledevice }

    var preferredBackend: BackendType {
        if hasPymobiledevice3 { return .pymobiledevice3 }
        if hasLibimobiledevice { return .libimobiledevice }
        return .none
    }

    enum BackendType: Sendable {
        case pymobiledevice3
        case libimobiledevice
        case none
    }
}

actor DependencyChecker {
    static let shared = DependencyChecker()
    private init() {}

    private var cachedStatus: DependencyStatus?

    func check(forceRefresh: Bool = false) async -> DependencyStatus {
        if !forceRefresh, let cached = cachedStatus {
            return cached
        }

        let runner = CommandRunner.shared
        async let pmd3 = runner.findExecutable("pymobiledevice3")
        async let ideviceset = runner.findExecutable("idevicesetlocation")
        async let ideviceid = runner.findExecutable("idevice_id")
        async let python = runner.findExecutable("python3")

        let (pmd3Path, idevicesetPath, ideviceidPath, pythonPath) =
            await (pmd3, ideviceset, ideviceid, python)

        var xcodeStatus = ToolStatus.notFound
        let xcodePath = "/Library/Developer/CommandLineTools/usr/bin/xcode-select"
        if FileManager.default.fileExists(atPath: xcodePath) ||
           FileManager.default.fileExists(atPath: "/usr/bin/xcode-select") {
            xcodeStatus = .available(path: "/usr/bin/xcode-select")
        }

        let status = DependencyStatus(
            pymobiledevice3: pmd3Path.map { .available(path: $0) } ?? .notFound,
            idevicesetlocation: idevicesetPath.map { .available(path: $0) } ?? .notFound,
            ideviceId: ideviceidPath.map { .available(path: $0) } ?? .notFound,
            xcodeCommandLineTools: xcodeStatus,
            python3: pythonPath.map { .available(path: $0) } ?? .notFound
        )

        cachedStatus = status
        return status
    }

    func invalidateCache() { cachedStatus = nil }
}
