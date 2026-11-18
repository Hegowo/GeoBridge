import SwiftUI
import Combine

@MainActor
final class SearchViewModel: ObservableObject {
    @Published var searchText: String = ""
    @Published var suggestions: [GeocodingSuggestion] = []
    @Published var isSearching: Bool = false
    @Published var searchError: String?

    private let geocodingService: any GeocodingServiceProtocol
    private var debounceTask: Task<Void, Never>?
    private let debounceInterval: Duration = .milliseconds(350)

    init(geocodingService: any GeocodingServiceProtocol = GeoplatformeService()) {
        self.geocodingService = geocodingService
    }

    func onTextChanged(_ newValue: String) {
        debounceTask?.cancel()
        searchError = nil

        guard !newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            suggestions = []
            isSearching = false
            return
        }

        debounceTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await Task.sleep(for: debounceInterval)
                guard !Task.isCancelled else { return }
                await self.performSearch(text: newValue)
            } catch is CancellationError {
                // debounced away — ignore
            } catch {}
        }
    }

    private func performSearch(text: String) async {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        isSearching = true
        defer { isSearching = false }

        do {
            let results = try await geocodingService.autocomplete(text: text)
            if !Task.isCancelled {
                suggestions = results
            }
        } catch is CancellationError {
            // ignore
        } catch {
            searchError = error.localizedDescription
            suggestions = []
        }
    }

    func clearSuggestions() {
        suggestions = []
        searchText = ""
        searchError = nil
        debounceTask?.cancel()
    }
}
