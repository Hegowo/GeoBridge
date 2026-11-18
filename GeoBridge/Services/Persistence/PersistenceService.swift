import Foundation

actor PersistenceService {
    static let shared = PersistenceService()
    private init() {}

    private var favoritesURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("GeoBridge", isDirectory: true)
            .appendingPathComponent("favorites.json")
    }

    private var recentsURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("GeoBridge", isDirectory: true)
            .appendingPathComponent("recents.json")
    }

    private func ensureDirectory() throws {
        let dir = favoritesURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    func loadFavorites() async -> [NamedLocation] {
        guard let data = try? Data(contentsOf: favoritesURL) else { return [] }
        return (try? JSONDecoder().decode([NamedLocation].self, from: data)) ?? []
    }

    func saveFavorites(_ locations: [NamedLocation]) async {
        guard let data = try? JSONEncoder().encode(locations) else { return }
        try? ensureDirectory()
        try? data.write(to: favoritesURL, options: .atomic)
    }

    func loadRecents() async -> [NamedLocation] {
        guard let data = try? Data(contentsOf: recentsURL) else { return [] }
        return (try? JSONDecoder().decode([NamedLocation].self, from: data)) ?? []
    }

    func saveRecents(_ locations: [NamedLocation]) async {
        let trimmed = Array(locations.prefix(20))   // keep last 20
        guard let data = try? JSONEncoder().encode(trimmed) else { return }
        try? ensureDirectory()
        try? data.write(to: recentsURL, options: .atomic)
    }
}
