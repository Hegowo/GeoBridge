import SwiftUI

struct LogsPanelView: View {
    @ObservedObject var appVM: AppViewModel
    @Binding var isExpanded: Bool
    @State private var showCopied = false

    var body: some View {
        VStack(spacing: 0) {
            // Header bar
            HStack(spacing: 8) {
                Button {
                    withAnimation(.spring(duration: 0.3)) { isExpanded.toggle() }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.caption)
                        Text("Logs")
                            .font(.caption.weight(.semibold))
                        if !appVM.logs.isEmpty {
                            Text("(\(appVM.logs.count))")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .buttonStyle(.plain)

                Spacer()

                if isExpanded {
                    Button {
                        copyLogs()
                    } label: {
                        Text(showCopied ? "Copied!" : "Copy")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)

                    Button {
                        appVM.clearLogs()
                    } label: {
                        Text("Clear")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.bar)

            if isExpanded {
                Divider()
                ScrollViewReader { scrollProxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 2) {
                            ForEach(appVM.logs) { entry in
                                LogRowView(entry: entry)
                                    .id(entry.id)
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                    }
                    .frame(height: 160)
                    .onChange(of: appVM.logs.count) { _, _ in
                        if let last = appVM.logs.last {
                            withAnimation { scrollProxy.scrollTo(last.id, anchor: .bottom) }
                        }
                    }
                }
            }
        }
    }

    private func copyLogs() {
        let text = appVM.exportLogs()
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        showCopied = true
        Task {
            try? await Task.sleep(for: .seconds(2))
            showCopied = false
        }
    }
}

private struct LogRowView: View {
    let entry: LogEntry

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Text(entry.formattedTime)
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.tertiary)
                .frame(width: 60, alignment: .leading)

            Text(entry.level.rawValue)
                .font(.system(.caption2, design: .monospaced).weight(.semibold))
                .foregroundStyle(levelColor)
                .frame(width: 36, alignment: .leading)

            Text(entry.message)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.primary)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(.vertical, 1)
    }

    private var levelColor: Color {
        switch entry.level {
        case .success: return .green
        case .error: return .red
        case .warning: return .orange
        case .command: return .blue
        case .output: return .secondary
        case .info: return .primary
        }
    }
}
