import SwiftUI
import MapKit

enum MapDisplayStyle { case standard, imagery }

struct MapContainerView: View {
    @ObservedObject var appVM: AppViewModel

    @State private var mapDisplayStyle: MapDisplayStyle = .standard
    @State private var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 48.8566, longitude: 2.3522),
            span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
        )
    )

    private var mapStyle: MapStyle {
        mapDisplayStyle == .standard ? .standard : .imagery
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            mapView

            mapControls
                .padding(12)
        }
        .onChange(of: appVM.mapRegionCenter) { _, center in
            withAnimation(.easeInOut(duration: 0.5)) {
                cameraPosition = .region(
                    MKCoordinateRegion(
                        center: center.clCoordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                    )
                )
            }
        }
    }

    // MARK: - Map

    private var mapView: some View {
        MapReader { proxy in
            Map(position: $cameraPosition, interactionModes: .all) {
                // Route polyline
                if let polyline = appVM.routePolyline, !polyline.isEmpty {
                    MapPolyline(coordinates: polyline)
                        .stroke(.blue.opacity(0.8), lineWidth: 5)
                }

                // Current position pin
                if let coord = appVM.selectedCoordinate {
                    Annotation("Selected", coordinate: coord.clCoordinate) {
                        PinView(isActive: appVM.deviceState.isSimulating,
                                isRoute: appVM.routePolyline != nil)
                    }
                }
            }
            .mapStyle(mapStyle)
            .onTapGesture { screenPoint in
                // Ignore taps during route simulation
                guard appVM.routePolyline == nil else { return }
                if let coordinate = proxy.convert(screenPoint, from: .local) {
                    appVM.setSelectedCoordinate(
                        latitude: coordinate.latitude,
                        longitude: coordinate.longitude
                    )
                }
            }
        }
    }

    // MARK: - Controls overlay

    private var mapControls: some View {
        VStack(spacing: 8) {
            // Style toggle
            Button {
                mapDisplayStyle = mapDisplayStyle == .standard ? .imagery : .standard
            } label: {
                Image(systemName: mapDisplayStyle == .standard ? "globe" : "map")
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.glass)
            .help(mapDisplayStyle == .standard ? "Switch to Satellite" : "Switch to Standard")

            // Recenter to selected
            if let coord = appVM.selectedCoordinate {
                Button {
                    withAnimation {
                        cameraPosition = .region(
                            MKCoordinateRegion(
                                center: coord.clCoordinate,
                                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                            )
                        )
                    }
                } label: {
                    Image(systemName: "location.viewfinder")
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.glass)
                .help("Centre on selected location")
            }
        }
    }
}

// MARK: - Pin View

private struct PinView: View {
    let isActive: Bool
    var isRoute: Bool = false

    @State private var pulse = false

    var body: some View {
        ZStack {
            if isActive {
                Circle()
                    .fill(pinColor.opacity(0.3))
                    .frame(width: 40, height: 40)
                    .scaleEffect(pulse ? 1.4 : 1.0)
                    .opacity(pulse ? 0 : 1)
                    .animation(.easeOut(duration: 1.2).repeatForever(autoreverses: false), value: pulse)
                    .onAppear { pulse = true }
            }

            Image(systemName: isRoute ? "figure.walk.circle.fill" : "mappin.circle.fill")
                .font(.system(size: 28))
                .foregroundStyle(pinColor)
                .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
        }
    }

    private var pinColor: Color {
        if isRoute { return .blue }
        return isActive ? .green : .red
    }
}

// MARK: - Glass button style

struct GlassButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                .regularMaterial,
                in: RoundedRectangle(cornerRadius: 8)
            )
            .opacity(configuration.isPressed ? 0.7 : 1.0)
    }
}

extension ButtonStyle where Self == GlassButtonStyle {
    static var glass: GlassButtonStyle { GlassButtonStyle() }
}
