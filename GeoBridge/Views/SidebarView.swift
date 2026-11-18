import SwiftUI

struct SidebarView: View {
    @ObservedObject var appVM:    AppViewModel
    @ObservedObject var searchVM: SearchViewModel
    @ObservedObject var routeVM:  RouteViewModel
    @Binding var showSetupGuide: Bool

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                DeviceCardView(appVM: appVM)

                if !appVM.isMockMode, appVM.dependencyStatus?.pymobiledevice3.isAvailable == true {
                    TunnelSectionView(appVM: appVM)
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Button {
                            Task { await appVM.refreshDevices() }
                        } label: {
                            Label("Refresh", systemImage: "arrow.clockwise")
                                .font(.caption)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .help("Rescan for connected devices")

                        Button {
                            showSetupGuide = true
                        } label: {
                            Label("Setup", systemImage: "questionmark.circle")
                                .font(.caption)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .help("Open Setup Guide")

                        Spacer()
                    }

                    if !appVM.isMockMode {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Scan via")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                            Picker("Scan via", selection: $appVM.connectionScanMode) {
                                ForEach(ConnectionScanMode.allCases) { mode in
                                    Text(mode.rawValue).tag(mode)
                                }
                            }
                            .pickerStyle(.segmented)
                            .labelsHidden()
                        }
                    }
                }

                Divider()

                SearchFieldView(appVM: appVM, searchVM: searchVM)

                Divider()

                CoordinateInputView(appVM: appVM)

                Divider()

                LocationActionView(appVM: appVM)

                Divider()

                RoutePlannerView(appVM: appVM, routeVM: routeVM)

                Divider()

                FavoritesListView(appVM: appVM)

                Spacer(minLength: 0)
            }
            .padding(12)
            .padding(.top, 40)
            }
            .ignoresSafeArea(.container, edges: .top)
            SidebarCreditsView()
        }
        .frame(minWidth: 280)
        .background(.background)
    }
}

private struct SidebarCreditsView: View {
    private let repositoryURL = URL(string: "https://github.com/Hegowo/GeoBridge")!

    private var appVersion: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "dev"
        let build = info?["CFBundleVersion"] as? String
        return build.map { "\(short) (\($0))" } ?? short
    }

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 6) {
                Link(destination: repositoryURL) {
                    GitHubMark()
                        .frame(width: 14, height: 14)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help(repositoryURL.absoluteString)
                Spacer()
                Text("by Kahodev · v\(appVersion)")
                    .foregroundStyle(.secondary)
            }
            .font(.caption)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .background(.background)
    }
}

private struct GitHubMark: View {
    private static let image: NSImage? = {
        let svg = #"<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 16 16" width="16" height="16"><path d="M8 0c4.42 0 8 3.58 8 8a8.013 8.013 0 0 1-5.45 7.59c-.4.08-.55-.17-.55-.38 0-.27.01-1.13.01-2.2 0-.75-.25-1.23-.54-1.48 1.78-.2 3.65-.88 3.65-3.95 0-.88-.31-1.59-.82-2.15.08-.2.36-1.02-.08-2.12 0 0-.67-.22-2.2.82-.64-.18-1.32-.27-2-.27-.68 0-1.36.09-2 .27-1.53-1.03-2.2-.82-2.2-.82-.44 1.1-.16 1.92-.08 2.12-.51.56-.82 1.28-.82 2.15 0 3.06 1.86 3.75 3.64 3.95-.23.2-.44.55-.51 1.07-.46.21-1.61.55-2.33-.66-.15-.24-.6-.83-1.23-.82-.67.01-.27.38.01.53.34.19.73.9.82 1.13.16.45.68 1.31 2.69.94 0 .67.01 1.3.01 1.49 0 .21-.15.45-.55.38A7.995 7.995 0 0 1 0 8c0-4.42 3.58-8 8-8Z"/></svg>"#
        let image = NSImage(data: Data(svg.utf8))
        image?.isTemplate = true
        return image
    }()

    var body: some View {
        if let image = Self.image {
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
        } else {
            Image(systemName: "chevron.left.forwardslash.chevron.right")
        }
    }
}

private struct TunnelSectionView: View {
    @ObservedObject var appVM: AppViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "point.3.connected.trianglepath.dotted")
                    .font(.caption)
                    .foregroundStyle(stateColor)
                Text("Tunnel Daemon")
                    .font(.caption.weight(.semibold))
                Spacer()
                Circle()
                    .fill(stateColor)
                    .frame(width: 7, height: 7)
            }

            Text(appVM.tunnelState.label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 6) {
                if appVM.tunnelState.isStarting {
                    ProgressView().scaleEffect(0.6)
                    Text("Starting…")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else if appVM.tunnelState.isRunning {
                    Button {
                        Task { await appVM.stopTunnelDaemon() }
                    } label: {
                        Label("Stop", systemImage: "stop.fill")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .tint(.red)
                } else {
                    Button {
                        Task { await appVM.startTunnelDaemon() }
                    } label: {
                        Label("Start Tunnel", systemImage: "play.fill")
                            .font(.caption)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }

                Spacer()
            }

            Text("Required for iOS 17+. Runs as root, persists until stopped.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .background(.quinary, in: RoundedRectangle(cornerRadius: 8))
    }

    private var stateColor: Color {
        switch appVM.tunnelState.colorName {
        case "green":  return .green
        case "orange": return .orange
        case "red":    return .red
        default:       return .secondary
        }
    }
}
