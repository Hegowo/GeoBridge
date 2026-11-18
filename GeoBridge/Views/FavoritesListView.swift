import SwiftUI

struct FavoritesListView: View {
    @ObservedObject var appVM: AppViewModel
    @State private var showAddFavorite = false
    @State private var newFavName = ""
    @State private var selectedTab: Tab = .favorites

    enum Tab: String, CaseIterable {
        case favorites = "Favourites"
        case recents = "Recent"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Picker("", selection: $selectedTab) {
                    ForEach(Tab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                if appVM.selectedCoordinate != nil && selectedTab == .favorites {
                    Button {
                        newFavName = appVM.selectedCoordinate?.formatted ?? ""
                        showAddFavorite = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(.plain)
                    .help("Save current location as favourite")
                }
            }

            let items = selectedTab == .favorites ? appVM.favorites : appVM.recentLocations

            if items.isEmpty {
                Text(selectedTab == .favorites ? "No favourites yet" : "No recent locations")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(items) { location in
                            LocationRowView(
                                location: location,
                                onSelect: { appVM.selectLocation(location) },
                                onDelete: selectedTab == .favorites
                                    ? { appVM.removeFavorite(location) }
                                    : nil
                            )
                            if location.id != items.last?.id {
                                Divider().padding(.leading, 8)
                            }
                        }
                    }
                }
                .frame(maxHeight: 180)
                .background(.quinary, in: RoundedRectangle(cornerRadius: 8))
            }
        }
        .sheet(isPresented: $showAddFavorite) {
            addFavouriteSheet
        }
    }

    private var addFavouriteSheet: some View {
        VStack(spacing: 16) {
            Text("Save Favourite")
                .font(.headline)
            TextField("Name", text: $newFavName)
                .textFieldStyle(.roundedBorder)
            if let coord = appVM.selectedCoordinate {
                Text(coord.formatted).font(.caption).foregroundStyle(.secondary)
            }
            HStack {
                Button("Cancel") { showAddFavorite = false }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Save") {
                    if let coord = appVM.selectedCoordinate {
                        appVM.addFavorite(name: newFavName, coordinate: coord)
                    }
                    showAddFavorite = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(newFavName.trimmingCharacters(in: .whitespaces).isEmpty)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 300)
    }
}

private struct LocationRowView: View {
    let location: NamedLocation
    let onSelect: () -> Void
    let onDelete: (() -> Void)?

    var body: some View {
        HStack {
            Button {
                onSelect()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: location.isFavorite ? "star.fill" : "clock")
                        .font(.caption)
                        .foregroundStyle(location.isFavorite ? .yellow : .secondary)
                        .frame(width: 14)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(location.name).font(.callout).lineLimit(1)
                        Text(location.coordinate.formatted)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)

            if let onDelete {
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Image(systemName: "trash")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .padding(.trailing, 8)
            }
        }
    }
}
