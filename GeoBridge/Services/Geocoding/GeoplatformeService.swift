import Foundation

protocol GeocodingServiceProtocol: Sendable {
    func autocomplete(text: String) async throws -> [GeocodingSuggestion]
}

/// Calls the French IGN Géoplateforme geocoding API.
/// No API key required. Restricted to French territory by default.
/// https://geoservices.ign.fr/services-geoplateforme-geocodage
final class GeoplatformeService: GeocodingServiceProtocol, @unchecked Sendable {
    private let session: URLSession
    private let decoder: JSONDecoder

    // Base URLs — no hard-coded credentials
    private let completionBase = "https://data.geopf.fr/geocodage/completion/"
    private let searchBase = "https://data.geopf.fr/geocodage/search"

    init(session: URLSession = .shared) {
        self.session = session
        decoder = JSONDecoder()
    }

    // MARK: - Autocomplete (primary)

    func autocomplete(text: String) async throws -> [GeocodingSuggestion] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { return [] }

        var components = URLComponents(string: completionBase)!
        components.queryItems = [
            URLQueryItem(name: "text", value: trimmed),
            URLQueryItem(name: "type", value: "StreetAddress,PositionOfInterest"),
            URLQueryItem(name: "maximumResponses", value: "10")
        ]

        guard let url = components.url else {
            throw AppError.networkError("Could not build autocomplete URL")
        }

        let data = try await fetchWithRetry(url: url)

        do {
            let response = try decoder.decode(CompletionResponse.self, from: data)
            return response.results.map { GeocodingSuggestion(from: $0) }
        } catch {
            // If completion parsing fails, fall back to search
            return try await search(text: trimmed)
        }
    }

    // MARK: - Search (fallback)

    private func search(text: String) async throws -> [GeocodingSuggestion] {
        var components = URLComponents(string: searchBase)!
        components.queryItems = [
            URLQueryItem(name: "q", value: text),
            URLQueryItem(name: "limit", value: "10")
        ]

        guard let url = components.url else {
            throw AppError.networkError("Could not build search URL")
        }

        let data = try await fetchWithRetry(url: url)
        let collection = try decoder.decode(SearchFeatureCollection.self, from: data)
        return collection.features.map { GeocodingSuggestion(from: $0) }
    }

    // MARK: - Networking

    private func fetchWithRetry(url: URL, maxAttempts: Int = 2) async throws -> Data {
        var lastError: Error?
        for attempt in 0..<maxAttempts {
            do {
                if attempt > 0 {
                    // Exponential backoff: 1s, 2s, …
                    try await Task.sleep(for: .seconds(Double(1 << (attempt - 1))))
                }
                guard !Task.isCancelled else { throw CancellationError() }

                let (data, response) = try await session.data(from: url)

                guard let httpResponse = response as? HTTPURLResponse else {
                    throw AppError.networkError("Non-HTTP response")
                }

                switch httpResponse.statusCode {
                case 200...299:
                    return data
                case 429:
                    // Rate limited — wait longer before retry
                    try await Task.sleep(for: .seconds(2))
                    lastError = AppError.networkError("Rate limited (HTTP 429)")
                default:
                    throw AppError.networkError("HTTP \(httpResponse.statusCode)")
                }
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                lastError = error
            }
        }
        throw lastError ?? AppError.networkError("Request failed")
    }
}
