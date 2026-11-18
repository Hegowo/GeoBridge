import SwiftUI

struct SearchFieldView: View {
    @ObservedObject var appVM: AppViewModel
    @ObservedObject var searchVM: SearchViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("Search Address", systemImage: "magnifyingglass")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                TextField("Type an address or place…", text: $searchVM.searchText)
                    .textFieldStyle(.plain)
                    .onChange(of: searchVM.searchText) { _, newValue in
                        searchVM.onTextChanged(newValue)
                    }

                if searchVM.isSearching {
                    ProgressView().scaleEffect(0.7)
                } else if !searchVM.searchText.isEmpty {
                    Button {
                        searchVM.clearSuggestions()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(.quinary, in: RoundedRectangle(cornerRadius: 8))

            if let error = searchVM.searchError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 4)
            }

            if !searchVM.suggestions.isEmpty {
                SuggestionsListView(suggestions: searchVM.suggestions) { suggestion in
                    selectSuggestion(suggestion)
                }
            }
        }
    }

    private func selectSuggestion(_ suggestion: GeocodingSuggestion) {
        guard let coord = suggestion.coordinate else { return }
        appVM.setSelectedCoordinate(latitude: coord.latitude, longitude: coord.longitude)
        appVM.mapRegionCenter = coord
        searchVM.clearSuggestions()
    }
}

private struct SuggestionsListView: View {
    let suggestions: [GeocodingSuggestion]
    let onSelect: (GeocodingSuggestion) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(suggestions) { suggestion in
                Button {
                    onSelect(suggestion)
                } label: {
                    HStack {
                        Image(systemName: "mappin")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 16)
                        Text(suggestion.displayText)
                            .font(.callout)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        Spacer()
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .background(.clear)
                .hoverEffect()

                if suggestion.id != suggestions.last?.id {
                    Divider().padding(.leading, 32)
                }
            }
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
    }
}

extension View {
    @ViewBuilder func hoverEffect() -> some View {
        self.onHover { inside in _ = inside }
    }
}
