import Foundation

struct NamedLocation: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var name: String
    var coordinate: Coordinate
    var isFavorite: Bool
    var lastUsed: Date

    init(id: UUID = UUID(), name: String, coordinate: Coordinate,
         isFavorite: Bool = false, lastUsed: Date = .now) {
        self.id = id
        self.name = name
        self.coordinate = coordinate
        self.isFavorite = isFavorite
        self.lastUsed = lastUsed
    }
}
