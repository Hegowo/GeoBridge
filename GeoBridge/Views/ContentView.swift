import SwiftUI

struct ContentView: View {
    @StateObject private var appVM    = AppViewModel()
    @StateObject private var searchVM = SearchViewModel()
    @StateObject private var routeVM  = RouteViewModel()

    @State private var showSetupGuide = false
    @State private var logsExpanded   = true

    var body: some View {
        NavigationSplitView {
            SidebarView(
                appVM: appVM,
                searchVM: searchVM,
                routeVM: routeVM,
                showSetupGuide: $showSetupGuide
            )
            .navigationSplitViewColumnWidth(min: 280, ideal: 320, max: 400)
        } detail: {
            VStack(spacing: 0) {
                MapContainerView(appVM: appVM)
                    .layoutPriority(1)
                Divider()
                LogsPanelView(appVM: appVM, isExpanded: $logsExpanded)
            }
        }
        .sheet(isPresented: $showSetupGuide) {
            SetupGuideView(appVM: appVM, showSetupGuide: $showSetupGuide)
        }
        // Dual-connection prompt — shown as a blocking alert so the user must choose.
        .alert(
            "Device on Multiple Connections",
            isPresented: Binding(
                get: { appVM.dualConnectionPrompt != nil },
                set: { if !$0 { appVM.dualConnectionPrompt = nil } }
            ),
            presenting: appVM.dualConnectionPrompt
        ) { prompt in
            Button("Use USB") {
                appVM.resolveConnectionChoice(udid: prompt.usbDevice.id, use: .usb)
            }
            Button("Use Wi-Fi") {
                appVM.resolveConnectionChoice(udid: prompt.wifiDevice.id, use: .wifi)
            }
            Button("Cancel", role: .cancel) {
                appVM.dualConnectionPrompt = nil
            }
        } message: { prompt in
            Text("\(prompt.usbDevice.displayName) is connected via both USB and Wi-Fi. Which connection should GeoBridge use?")
        }
        .task {
            await appVM.initialize()
        }
        .onReceive(
            NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)
        ) { _ in
            Task { await appVM.handleAppTermination() }
        }
    }
}

#Preview {
    ContentView()
        .frame(width: 1100, height: 740)
}
