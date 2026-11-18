import SwiftUI

struct SetupGuideView: View {
    @ObservedObject var appVM: AppViewModel
    @Binding var showSetupGuide: Bool

    @State private var checkingDeps = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                depStatusSection

                Divider()

                installSection

                Divider()

                deviceSetupSection

                Divider()

                troubleshootSection
            }
            .padding(24)
        }
        .frame(width: 560, height: 640)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") { showSetupGuide = false }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    Task {
                        checkingDeps = true
                        let fresh = await DependencyChecker.shared.check(forceRefresh: true)
                        appVM.dependencyStatus = fresh
                        checkingDeps = false
                    }
                } label: {
                    HStack(spacing: 4) {
                        if checkingDeps { ProgressView().scaleEffect(0.7) }
                        Text("Re-check Dependencies")
                    }
                }
                .disabled(checkingDeps)
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "map.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.blue)
                VStack(alignment: .leading) {
                    Text("GeoBridge Setup Guide")
                        .font(.title2.weight(.semibold))
                    Text("Developer location simulation for iPhone")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            Text("GeoBridge uses legitimate Apple developer tools to simulate GPS on your own iPhone. It does not jailbreak the device or bypass Apple security.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Dependency Status

    private var depStatusSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Dependencies").font(.headline)

            if let status = appVM.dependencyStatus {
                DepRow(name: "pymobiledevice3 (recommended)", status: status.pymobiledevice3)
                DepRow(name: "idevicesetlocation (fallback)", status: status.idevicesetlocation)
                DepRow(name: "idevice_id (libimobiledevice)", status: status.ideviceId)
                DepRow(name: "Python 3", status: status.python3)
                DepRow(name: "Xcode Command Line Tools", status: status.xcodeCommandLineTools)
            } else {
                ProgressView("Checking…")
            }
        }
    }

    // MARK: - Install

    private var installSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Installation").font(.headline)

            StepCard(number: "1", title: "Install Homebrew (if needed)") {
                CodeBlock(text: "/bin/bash -c \"$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\"")
            }

            StepCard(number: "2", title: "Install pymobiledevice3 (recommended)") {
                CodeBlock(text: "pip3 install pymobiledevice3")
                Text("or")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                CodeBlock(text: "brew install python && pip3 install pymobiledevice3")
            }

            StepCard(number: "2b", title: "Or install libimobiledevice (alternative)") {
                CodeBlock(text: "brew install libimobiledevice ideviceinstaller")
            }

            if appVM.dependencyStatus?.pymobiledevice3.isAvailable == false &&
               appVM.dependencyStatus?.idevicesetlocation.isAvailable == false {
                Label("No backend detected. Install one of the above.", systemImage: "exclamationmark.triangle.fill")
                    .font(.callout)
                    .foregroundStyle(.orange)
            }
        }
    }

    // MARK: - Device Setup

    private var deviceSetupSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("iPhone Setup").font(.headline)

            StepCard(number: "1", title: "Enable Developer Mode (iOS 16+)") {
                Text("Settings → Privacy & Security → Developer Mode → Enable → Reboot → Confirm")
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
            }

            StepCard(number: "2", title: "Trust this Mac") {
                Text("Connect via USB, unlock your iPhone, and tap \"Trust This Computer\" when prompted.")
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
            }

            StepCard(number: "3", title: "iOS 17+ Tunnel — required for all modern iPhones") {
                Text("Open a new Terminal window and run (it will ask for your Mac password):")
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
                CodeBlock(text: "sudo ~/.local/bin/pymobiledevice3 remote tunneld")
                Text("Keep that Terminal window open the entire time you use GeoBridge. The tunnel provides the secure channel DVT needs for location simulation.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Mock mode toggle
            VStack(alignment: .leading, spacing: 6) {
                Text("Demo Mode").font(.subheadline.weight(.medium))
                Text("Use the mock backend to explore the UI without a real iPhone.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Toggle("Enable Mock Mode", isOn: Binding(
                    get: { appVM.isMockMode },
                    set: { newValue in
                        if newValue { appVM.enableMockMode() }
                        else { appVM.disableMockMode() }
                    }
                ))
                .toggleStyle(.switch)
                .controlSize(.small)
            }
            .padding(12)
            .background(.quinary, in: RoundedRectangle(cornerRadius: 8))
        }
    }

    // MARK: - Troubleshoot

    private var troubleshootSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Troubleshooting").font(.headline)

            TroubleshootRow(
                question: "Device shows as \"not trusted\"",
                answer: "Unlock the iPhone and tap \"Trust\" in the dialog. Replug the cable."
            )
            TroubleshootRow(
                question: "Developer Mode shows as required",
                answer: "iOS 16+: Settings → Privacy & Security → Developer Mode → Enable. Reboot when prompted."
            )
            TroubleshootRow(
                question: "Location not changing on iOS 17+",
                answer: "Start a tunnel: sudo pymobiledevice3 remote tunneld. Keep it running."
            )
            TroubleshootRow(
                question: "Reset real location",
                answer: "Click \"Reset Real Location\" in the sidebar, or quit GeoBridge and restart the Maps app."
            )
            TroubleshootRow(
                question: "pymobiledevice3 not found after install",
                answer: "Check your PATH. Try: pip3 show pymobiledevice3 and ensure the bin directory is in PATH."
            )

            Text("Security Notice")
                .font(.subheadline.weight(.medium))
                .padding(.top, 8)
            Text("GeoBridge only works with your own iPhone connected via USB. It uses Apple developer APIs — no jailbreaking, no exploit, no third-party servers. Location simulation stops the moment you reset or disconnect.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Helpers

private struct DepRow: View {
    let name: String
    let status: ToolStatus

    var body: some View {
        HStack {
            Image(systemName: status.isAvailable ? "checkmark.circle.fill" : "xmark.circle")
                .foregroundStyle(status.isAvailable ? .green : .secondary)
            Text(name).font(.callout)
            Spacer()
            if let path = status.path {
                Text(path)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.head)
                    .frame(maxWidth: 200, alignment: .trailing)
            } else {
                Text("Not found").font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

private struct StepCard<Content: View>: View {
    let number: String
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(Circle().fill(.blue))
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.callout.weight(.medium))
                content
            }
        }
    }
}

private struct CodeBlock: View {
    let text: String
    @State private var copied = false

    var body: some View {
        HStack {
            Text(text)
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(text, forType: .string)
                copied = true
                Task {
                    try? await Task.sleep(for: .seconds(1.5))
                    copied = false
                }
            } label: {
                Text(copied ? "Copied" : "Copy")
                    .font(.caption2)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding(8)
        .background(.quinary, in: RoundedRectangle(cornerRadius: 6))
    }
}

private struct TroubleshootRow: View {
    let question: String
    let answer: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .top, spacing: 6) {
                Image(systemName: "questionmark.circle").font(.caption).foregroundStyle(.blue)
                Text(question).font(.callout.weight(.medium))
            }
            Text(answer)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.leading, 18)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
