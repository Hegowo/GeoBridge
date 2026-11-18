import SwiftUI

struct DeviceCardView: View {
    @ObservedObject var appVM: AppViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "iphone")
                    .font(.title2)
                    .foregroundStyle(statusColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text(deviceName)
                        .font(.headline)
                        .lineLimit(1)
                    Text(appVM.deviceState.statusLabel)
                        .font(.caption)
                        .foregroundStyle(statusColor)
                }
                Spacer()
                statusBadge
            }

            if let device = appVM.deviceState.device {
                Divider()
                HStack(spacing: 16) {
                    InfoChip(label: "iOS", value: device.iOSVersion)
                    ConnectionChip(connectionType: device.connectionType)
                }
            }

            if case .simulationActive(_, let coord) = appVM.deviceState {
                Divider()
                HStack {
                    Image(systemName: "location.fill")
                        .foregroundStyle(.green)
                        .font(.caption)
                    Text("Simulated: \(coord.formatted)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            contextualHint
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Sub-views

    private var statusBadge: some View {
        Circle()
            .fill(statusColor)
            .frame(width: 10, height: 10)
    }

    @ViewBuilder
    private var contextualHint: some View {
        switch appVM.deviceState {
        case .notTrusted:
            HintBanner(
                icon: "lock.shield",
                text: "Unlock iPhone and tap \"Trust This Computer\"",
                color: .orange
            )
        case .developerModeRequired:
            HintBanner(
                icon: "hammer",
                text: "Settings → Privacy & Security → Developer Mode → Enable",
                color: .orange
            )
        case .error(_, let err):
            HintBanner(icon: "exclamationmark.triangle", text: err.errorDescription ?? "", color: .red)
        default:
            EmptyView()
        }
    }

    // MARK: - Helpers

    private var deviceName: String {
        appVM.deviceState.device?.displayName ?? "No Device"
    }

    private var statusColor: Color {
        switch appVM.deviceState.statusColor {
        case "green": return .green
        case "orange": return .orange
        case "red": return .red
        case "blue": return .blue
        default: return .secondary
        }
    }
}

private struct ConnectionChip: View {
    let connectionType: IOSDevice.ConnectionType

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("Connection").font(.caption2).foregroundStyle(.tertiary)
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundStyle(iconColor)
                Text(label)
                    .font(.caption)
                    .fontWeight(.medium)
            }
        }
    }

    private var icon: String {
        switch connectionType {
        case .usb:     return "cable.connector"
        case .wifi:    return "wifi"
        case .unknown: return "questionmark.circle"
        }
    }

    private var iconColor: Color {
        switch connectionType {
        case .usb:     return .secondary
        case .wifi:    return .blue
        case .unknown: return .secondary
        }
    }

    private var label: String {
        switch connectionType {
        case .usb:     return "USB"
        case .wifi:    return "Wi-Fi"
        case .unknown: return "Unknown"
        }
    }
}

private struct InfoChip: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label).font(.caption2).foregroundStyle(.tertiary)
            Text(value).font(.caption).fontWeight(.medium)
        }
    }
}

private struct HintBanner: View {
    let icon: String
    let text: String
    let color: Color

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
                .padding(.top, 1)
            Text(text)
                .font(.caption)
                .foregroundStyle(color)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 4)
    }
}
