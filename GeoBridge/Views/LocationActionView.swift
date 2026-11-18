import SwiftUI

struct LocationActionView: View {
    @ObservedObject var appVM: AppViewModel
    @State private var showResetConfirm = false

    var body: some View {
        VStack(spacing: 8) {
            Button {
                Task { await appVM.changeLocation() }
            } label: {
                HStack {
                    if case .applyingLocation = appVM.deviceState {
                        ProgressView().scaleEffect(0.8).padding(.trailing, 4)
                    } else {
                        Image(systemName: "location.fill")
                    }
                    Text(actionButtonTitle)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!appVM.canChangeLocation || isApplying)

            if appVM.canResetLocation {
                Button(role: .destructive) {
                    showResetConfirm = true
                } label: {
                    Label("Reset Real Location", systemImage: "location.slash")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .confirmationDialog(
                    "Clear simulated location?",
                    isPresented: $showResetConfirm,
                    titleVisibility: .visible
                ) {
                    Button("Reset to Real GPS", role: .destructive) {
                        Task { await appVM.resetLocation() }
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("Your iPhone will return to using its real GPS signal.")
                }
            }
        }
    }

    private var actionButtonTitle: String {
        if case .applyingLocation = appVM.deviceState { return "Applying…" }
        return "Change Location"
    }

    private var isApplying: Bool {
        if case .applyingLocation = appVM.deviceState { return true }
        return false
    }
}
