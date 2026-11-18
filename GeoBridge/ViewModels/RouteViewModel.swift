import SwiftUI
import MapKit
import CoreLocation

// MARK: - Input mode

enum RouteInputMode: String, CaseIterable, Identifiable {
    case address     = "Address"
    case coordinates = "Coordinates"
    var id: String { rawValue }
}

// MARK: - Route state

enum RouteState: Equatable {
    case idle
    case geocoding
    case calculatingRoute
    case ready(PlannedRoute)
    case simulating(PlannedRoute, progress: Double)
    case paused(PlannedRoute, progress: Double)
    case completed
    case error(String)

    static func == (lhs: RouteState, rhs: RouteState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.geocoding, .geocoding),
             (.calculatingRoute, .calculatingRoute), (.completed, .completed): return true
        case (.error(let a), .error(let b)): return a == b
        default: return false
        }
    }

    var route: PlannedRoute? {
        switch self {
        case .ready(let r): return r
        case .simulating(let r, _): return r
        case .paused(let r, _): return r
        default: return nil
        }
    }

    var progress: Double {
        switch self {
        case .simulating(_, let p): return p
        case .paused(_, let p): return p
        default: return 0
        }
    }

    var isSimulating: Bool { if case .simulating = self { return true }; return false }
    var isPaused: Bool     { if case .paused    = self { return true }; return false }
    var isRunning: Bool    { isSimulating || isPaused }
    var isWorking: Bool {
        switch self { case .geocoding, .calculatingRoute: return true; default: return false }
    }
}

// MARK: - ViewModel

@MainActor
final class RouteViewModel: ObservableObject {

    // ── Start field ────────────────────────────────────────────
    @Published var startInputMode: RouteInputMode = .address
    @Published var startText: String = ""
    @Published var startLatText: String = ""
    @Published var startLonText: String = ""
    @Published var startSuggestions: [GeocodingSuggestion] = []
    @Published var startSearching: Bool = false
    @Published var startResolvedCoord: Coordinate? = nil   // set when user picks a suggestion

    // ── End field ──────────────────────────────────────────────
    @Published var endInputMode: RouteInputMode = .address
    @Published var endText: String = ""
    @Published var endLatText: String = ""
    @Published var endLonText: String = ""
    @Published var endSuggestions: [GeocodingSuggestion] = []
    @Published var endSearching: Bool = false
    @Published var endResolvedCoord: Coordinate? = nil

    // ── Other ──────────────────────────────────────────────────
    @Published var transportMode: TransportMode = .walking
    @Published var speedMultiplier: Double = 10.0
    @Published var state: RouteState = .idle

    private let geocodingService: any GeocodingServiceProtocol = GeoplatformeService()
    private var startDebounce: Task<Void, Never>?
    private var endDebounce:   Task<Void, Never>?
    private var simulationTask: Task<Void, Never>?
    private var currentProgress: Double = 0

    // MARK: - Address field text changes

    func onStartTextChanged(_ text: String) {
        startResolvedCoord = nil     // text changed → old suggestion no longer valid
        startDebounce?.cancel()
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            startSuggestions = []; return
        }
        startDebounce = Task { [weak self] in
            guard let self else { return }
            do {
                try await Task.sleep(for: .milliseconds(350))
                guard !Task.isCancelled else { return }
                await self.fetchStartSuggestions(text: text)
            } catch {}
        }
    }

    func onEndTextChanged(_ text: String) {
        endResolvedCoord = nil
        endDebounce?.cancel()
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            endSuggestions = []; return
        }
        endDebounce = Task { [weak self] in
            guard let self else { return }
            do {
                try await Task.sleep(for: .milliseconds(350))
                guard !Task.isCancelled else { return }
                await self.fetchEndSuggestions(text: text)
            } catch {}
        }
    }

    private func fetchStartSuggestions(text: String) async {
        startSearching = true
        defer { startSearching = false }
        startSuggestions = (try? await geocodingService.autocomplete(text: text)) ?? []
    }

    private func fetchEndSuggestions(text: String) async {
        endSearching = true
        defer { endSearching = false }
        endSuggestions = (try? await geocodingService.autocomplete(text: text)) ?? []
    }

    func selectStartSuggestion(_ suggestion: GeocodingSuggestion) {
        startText = suggestion.displayText
        startResolvedCoord = suggestion.coordinate
        startSuggestions = []
        startDebounce?.cancel()
    }

    func selectEndSuggestion(_ suggestion: GeocodingSuggestion) {
        endText = suggestion.displayText
        endResolvedCoord = suggestion.coordinate
        endSuggestions = []
        endDebounce?.cancel()
    }

    func clearStart() {
        startText = ""; startLatText = ""; startLonText = ""
        startSuggestions = []; startResolvedCoord = nil
        startDebounce?.cancel()
    }

    func clearEnd() {
        endText = ""; endLatText = ""; endLonText = ""
        endSuggestions = []; endResolvedCoord = nil
        endDebounce?.cancel()
    }

    // MARK: - Route Calculation

    func calculateRoute(appVM: AppViewModel) async {
        guard hasValidInput else {
            state = .error("Fill in both the start and end fields.")
            return
        }

        state = .geocoding
        appVM.routePolyline = nil

        do {
            let startCoord = try await resolveCoord(
                mode: startInputMode,
                text: startText, resolved: startResolvedCoord,
                latText: startLatText, lonText: startLonText,
                label: "start"
            )
            let endCoord = try await resolveCoord(
                mode: endInputMode,
                text: endText, resolved: endResolvedCoord,
                latText: endLatText, lonText: endLonText,
                label: "end"
            )

            state = .calculatingRoute

            let request = MKDirections.Request()
            request.source      = MKMapItem(placemark: MKPlacemark(coordinate: startCoord))
            request.destination = MKMapItem(placemark: MKPlacemark(coordinate: endCoord))
            request.transportType = transportMode.mkTransportType

            let response = try await MKDirections(request: request).calculate()
            guard let mkRoute = response.routes.first else {
                state = .error("No route found between the two points.")
                return
            }

            let coords  = polylineCoords(from: mkRoute.polyline)
            let steps   = mkRoute.steps
                .filter { !$0.instructions.isEmpty }
                .map    { RouteStep(instructions: $0.instructions, distance: $0.distance) }

            let planned = PlannedRoute(
                transportMode: transportMode,
                totalDistance: mkRoute.distance,
                expectedTravelTime: mkRoute.expectedTravelTime,
                polylineCoordinates: coords,
                steps: steps
            )

            state = .ready(planned)
            appVM.routePolyline = coords

            if let first = coords.first {
                appVM.setSelectedCoordinate(latitude: first.latitude, longitude: first.longitude)
                appVM.mapRegionCenter = Coordinate(latitude: first.latitude, longitude: first.longitude)
            }

        } catch let err as RouteInputError {
            state = .error(err.message)
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    // MARK: - Resolve one endpoint to CLLocationCoordinate2D

    private func resolveCoord(
        mode: RouteInputMode,
        text: String, resolved: Coordinate?,
        latText: String, lonText: String,
        label: String
    ) async throws -> CLLocationCoordinate2D {

        switch mode {
        case .coordinates:
            guard let lat = Double(latText.trimmingCharacters(in: .whitespaces)),
                  let lon = Double(lonText.trimmingCharacters(in: .whitespaces)),
                  lat >= -90, lat <= 90, lon >= -180, lon <= 180 else {
                throw RouteInputError("Invalid coordinates for \(label).")
            }
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)

        case .address:
            // Already resolved by suggestion selection
            if let c = resolved {
                return CLLocationCoordinate2D(latitude: c.latitude, longitude: c.longitude)
            }
            // Typed text: try to parse as "lat, lon" first, then geocode
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if let c = parseCoordinate(trimmed) { return c }
            let placemarks = try await CLGeocoder().geocodeAddressString(trimmed)
            guard let c = placemarks.first?.location?.coordinate else {
                throw RouteInputError("\(label.capitalized) address not found: \(trimmed)")
            }
            return c
        }
    }

    // MARK: - Simulation Control

    func startSimulation(appVM: AppViewModel) {
        guard let route = state.route else { return }
        currentProgress = 0
        state = .simulating(route, progress: 0)
        launchSimulation(route: route, appVM: appVM)
    }

    func pauseSimulation() {
        simulationTask?.cancel()
        simulationTask = nil
        if case .simulating(let route, let p) = state { state = .paused(route, progress: p) }
    }

    func resumeSimulation(appVM: AppViewModel) {
        guard case .paused(let route, let p) = state else { return }
        currentProgress = p
        state = .simulating(route, progress: p)
        launchSimulation(route: route, appVM: appVM)
    }

    func stopSimulation(appVM: AppViewModel) {
        simulationTask?.cancel()
        simulationTask = nil
        currentProgress = 0
        state = .idle
        appVM.routePolyline = nil
        Task { await appVM.resetLocation() }
    }

    // MARK: - Simulation loop

    private func launchSimulation(route: PlannedRoute, appVM: AppViewModel) {
        simulationTask?.cancel()

        let coords     = route.polylineCoordinates
        let cumulative = cumulativeDistances(coords)
        let total      = cumulative.last ?? 0
        guard total > 0 else { return }

        // 2 s between position updates: short enough for smooth movement,
        // long enough for pymobiledevice3 to complete its DVT handshake.
        let interval   = 2.0
        let multiplier = speedMultiplier
        let speed      = route.transportMode.defaultMetersPerSecond
        let step       = interval * multiplier * speed
        var covered    = currentProgress * total

        simulationTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                let coord = interpolate(coords: coords, cumulative: cumulative, at: covered)
                await appVM.setRouteLocation(latitude: coord.latitude, longitude: coord.longitude)

                let progress = min(covered / total, 1.0)
                self.currentProgress = progress
                self.state = .simulating(route, progress: progress)

                if covered >= total { self.state = .completed; break }
                covered += step
                try? await Task.sleep(for: .seconds(interval))
            }
        }
    }

    // MARK: - Helpers

    var hasValidInput: Bool {
        switch (startInputMode, endInputMode) {
        case (.address, .address):
            return !startText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                   !endText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case (.coordinates, .address):
            return !startLatText.isEmpty && !startLonText.isEmpty &&
                   !endText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case (.address, .coordinates):
            return !startText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                   !endLatText.isEmpty && !endLonText.isEmpty
        case (.coordinates, .coordinates):
            return !startLatText.isEmpty && !startLonText.isEmpty &&
                   !endLatText.isEmpty && !endLonText.isEmpty
        }
    }

    private func parseCoordinate(_ text: String) -> CLLocationCoordinate2D? {
        let parts = text.replacingOccurrences(of: ",", with: " ")
            .split(separator: " ")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        guard parts.count == 2,
              let lat = Double(parts[0]), let lon = Double(parts[1]),
              lat >= -90, lat <= 90, lon >= -180, lon <= 180 else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    private func polylineCoords(from polyline: MKPolyline) -> [CLLocationCoordinate2D] {
        var out = [CLLocationCoordinate2D](repeating: .init(), count: polyline.pointCount)
        polyline.getCoordinates(&out, range: NSRange(location: 0, length: polyline.pointCount))
        return out
    }

    private func cumulativeDistances(_ coords: [CLLocationCoordinate2D]) -> [Double] {
        var result = [Double](repeating: 0, count: coords.count)
        for i in 1..<coords.count {
            let a = CLLocation(latitude: coords[i-1].latitude, longitude: coords[i-1].longitude)
            let b = CLLocation(latitude: coords[i].latitude,   longitude: coords[i].longitude)
            result[i] = result[i-1] + a.distance(from: b)
        }
        return result
    }

    private func interpolate(
        coords: [CLLocationCoordinate2D],
        cumulative: [Double],
        at distance: Double
    ) -> CLLocationCoordinate2D {
        let d = min(distance, cumulative.last ?? 0)
        var lo = 0, hi = max(0, cumulative.count - 1)
        while lo < hi - 1 {
            let mid = (lo + hi) / 2
            if cumulative[mid] <= d { lo = mid } else { hi = mid }
        }
        let segLen = cumulative[hi] - cumulative[lo]
        guard segLen > 0 else { return coords[lo] }
        let t   = (d - cumulative[lo]) / segLen
        let lat = coords[lo].latitude  + t * (coords[hi].latitude  - coords[lo].latitude)
        let lon = coords[lo].longitude + t * (coords[hi].longitude - coords[lo].longitude)
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
}

// MARK: - Input error

private struct RouteInputError: Error {
    let message: String
    init(_ message: String) { self.message = message }
}
