import SwiftUI
import MapKit

struct RoutePlannerView: View {
    @ObservedObject var appVM:   AppViewModel
    @ObservedObject var routeVM: RouteViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {

            // ── Section header ──────────────────────────────────────────
            Label("Route Simulation", systemImage: "road.lanes")
                .font(.caption)
                .foregroundStyle(.secondary)

            // ── Start field ─────────────────────────────────────────────
            endpointField(
                label: "Start",
                dotColor: .green,
                inputMode: $routeVM.startInputMode,
                addressText: $routeVM.startText,
                latText: $routeVM.startLatText,
                lonText: $routeVM.startLonText,
                isSearching: routeVM.startSearching,
                suggestions: routeVM.startSuggestions,
                onTextChange: { routeVM.onStartTextChanged($0) },
                onSelectSuggestion: { routeVM.selectStartSuggestion($0) },
                onClear: { routeVM.clearStart() }
            )

            // ── End field ───────────────────────────────────────────────
            endpointField(
                label: "End",
                dotColor: .red,
                inputMode: $routeVM.endInputMode,
                addressText: $routeVM.endText,
                latText: $routeVM.endLatText,
                lonText: $routeVM.endLonText,
                isSearching: routeVM.endSearching,
                suggestions: routeVM.endSuggestions,
                onTextChange: { routeVM.onEndTextChanged($0) },
                onSelectSuggestion: { routeVM.selectEndSuggestion($0) },
                onClear: { routeVM.clearEnd() }
            )

            // ── Transport mode ──────────────────────────────────────────
            HStack(spacing: 6) {
                ForEach(TransportMode.allCases) { mode in
                    transportButton(mode)
                }
            }
            .disabled(routeVM.state.isWorking || routeVM.state.isRunning)

            // ── Error ───────────────────────────────────────────────────
            if case .error(let msg) = routeVM.state {
                Text(msg)
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // ── Calculate button ────────────────────────────────────────
            Button {
                Task { await routeVM.calculateRoute(appVM: appVM) }
            } label: {
                HStack(spacing: 4) {
                    if routeVM.state.isWorking {
                        ProgressView().scaleEffect(0.6)
                        Text(routeVM.state == .geocoding ? "Finding addresses…" : "Calculating…")
                    } else {
                        Image(systemName: "arrow.triangle.turn.up.right.diamond")
                        Text(routeVM.state.route != nil ? "Recalculate" : "Calculate Route")
                    }
                }
                .frame(maxWidth: .infinity)
                .font(.caption)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(routeVM.state.isWorking || routeVM.state.isRunning || !routeVM.hasValidInput)

            // ── Route info + simulation controls ────────────────────────
            if let route = routeVM.state.route {
                routeInfoRow(route)
                simulationControls(route)
            }

            // ── Completed banner ────────────────────────────────────────
            if case .completed = routeVM.state {
                completedBanner
            }
        }
    }

    // MARK: - Endpoint field

    @ViewBuilder
    private func endpointField(
        label: String,
        dotColor: Color,
        inputMode: Binding<RouteInputMode>,
        addressText: Binding<String>,
        latText: Binding<String>,
        lonText: Binding<String>,
        isSearching: Bool,
        suggestions: [GeocodingSuggestion],
        onTextChange: @escaping (String) -> Void,
        onSelectSuggestion: @escaping (GeocodingSuggestion) -> Void,
        onClear: @escaping () -> Void
    ) -> some View {
        let locked = routeVM.state.isWorking || routeVM.state.isRunning

        VStack(alignment: .leading, spacing: 5) {
            // Row: dot + label + mode toggle
            HStack(spacing: 6) {
                Image(systemName: "circle.fill")
                    .font(.system(size: 7))
                    .foregroundStyle(dotColor)

                Text(label)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)

                Spacer()

                Picker("", selection: inputMode) {
                    ForEach(RouteInputMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 148)
                .disabled(locked)
            }

            // Input depending on mode
            if inputMode.wrappedValue == .address {
                // Address text field
                HStack(spacing: 4) {
                    TextField("Address or place…", text: addressText)
                        .textFieldStyle(.plain)
                        .font(.caption)
                        .onChange(of: addressText.wrappedValue, { _, v in onTextChange(v) })
                        .disabled(locked)

                    if isSearching {
                        ProgressView().scaleEffect(0.55)
                    } else if !addressText.wrappedValue.isEmpty {
                        Button { onClear() } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                                .font(.caption2)
                        }
                        .buttonStyle(.plain)
                        .disabled(locked)
                    }
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 5)
                .background(.quinary, in: RoundedRectangle(cornerRadius: 6))

                // Suggestions dropdown
                if !suggestions.isEmpty {
                    suggestionsList(suggestions: suggestions, onSelect: onSelectSuggestion)
                }

            } else {
                // Coordinate fields
                HStack(spacing: 6) {
                    coordField(placeholder: "Latitude", text: latText)
                    coordField(placeholder: "Longitude", text: lonText)
                }
                .disabled(locked)
            }
        }
    }

    private func coordField(placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
            .textFieldStyle(.plain)
            .multilineTextAlignment(.center)
            .font(.system(.caption, design: .monospaced))
            .padding(.horizontal, 7)
            .padding(.vertical, 5)
            .background(.quinary, in: RoundedRectangle(cornerRadius: 6))
            .frame(maxWidth: .infinity)
    }

    // MARK: - Suggestions list

    private func suggestionsList(
        suggestions: [GeocodingSuggestion],
        onSelect: @escaping (GeocodingSuggestion) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(suggestions) { suggestion in
                Button { onSelect(suggestion) } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "mappin")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .frame(width: 12)
                        Text(suggestion.displayText)
                            .font(.caption)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        Spacer()
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if suggestion.id != suggestions.last?.id {
                    Divider().padding(.leading, 26)
                }
            }
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 7))
        .shadow(color: .black.opacity(0.1), radius: 3, y: 2)
    }

    // MARK: - Transport button

    private func transportButton(_ mode: TransportMode) -> some View {
        let selected = routeVM.transportMode == mode
        return Button {
            routeVM.transportMode = mode
        } label: {
            HStack(spacing: 3) {
                Image(systemName: mode.systemImage).font(.caption2)
                Text(mode.rawValue).font(.caption2)
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(selected ? Color.accentColor : Color.secondary.opacity(0.12),
                        in: RoundedRectangle(cornerRadius: 5))
            .foregroundStyle(selected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Route info row

    private func routeInfoRow(_ route: PlannedRoute) -> some View {
        HStack(spacing: 8) {
            infoChip(icon: "ruler", value: route.formattedDistance)
            infoChip(icon: "clock", value: route.formattedDuration)
            Spacer()
        }
    }

    private func infoChip(icon: String, value: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.caption2).foregroundStyle(.blue)
            Text(value).font(.caption2.weight(.semibold))
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(.quinary, in: RoundedRectangle(cornerRadius: 5))
    }

    // MARK: - Simulation controls

    private func simulationControls(_ route: PlannedRoute) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Speed picker (hidden while simulation is running)
            if !routeVM.state.isRunning {
                HStack(spacing: 0) {
                    Text("Speed ")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Picker("", selection: $routeVM.speedMultiplier) {
                        Text("1×").tag(1.0)
                        Text("5×").tag(5.0)
                        Text("10×").tag(10.0)
                        Text("20×").tag(20.0)
                        Text("50×").tag(50.0)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(maxWidth: .infinity)
                }
            }

            // Progress bar
            if routeVM.state.progress > 0 {
                VStack(alignment: .leading, spacing: 2) {
                    ProgressView(value: routeVM.state.progress).tint(.blue)
                    HStack {
                        Text(String(format: "%.0f%%", routeVM.state.progress * 100))
                            .font(.caption2).foregroundStyle(.secondary)
                        Spacer()
                        if routeVM.state.isRunning {
                            let rem = route.expectedTravelTime * (1 - routeVM.state.progress) / routeVM.speedMultiplier
                            Text("~\(formatSeconds(rem))")
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }
            }

            // Action buttons
            HStack(spacing: 6) {
                switch routeVM.state {
                case .ready:
                    Button { routeVM.startSimulation(appVM: appVM) } label: {
                        Label("Start", systemImage: "play.fill").font(.caption)
                    }
                    .buttonStyle(.borderedProminent).controlSize(.small).tint(.green)

                case .simulating:
                    Button { routeVM.pauseSimulation() } label: {
                        Label("Pause", systemImage: "pause.fill").font(.caption)
                    }
                    .buttonStyle(.borderedProminent).controlSize(.small).tint(.orange)

                    Button { routeVM.stopSimulation(appVM: appVM) } label: {
                        Label("Stop", systemImage: "stop.fill").font(.caption)
                    }
                    .buttonStyle(.bordered).controlSize(.small).tint(.red)

                case .paused:
                    Button { routeVM.resumeSimulation(appVM: appVM) } label: {
                        Label("Resume", systemImage: "play.fill").font(.caption)
                    }
                    .buttonStyle(.borderedProminent).controlSize(.small).tint(.green)

                    Button { routeVM.stopSimulation(appVM: appVM) } label: {
                        Label("Stop", systemImage: "stop.fill").font(.caption)
                    }
                    .buttonStyle(.bordered).controlSize(.small).tint(.red)

                default: EmptyView()
                }
                Spacer()
            }

            // Directions disclosure
            if !route.steps.isEmpty {
                DisclosureGroup {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(route.steps.enumerated()), id: \.offset) { _, step in
                            HStack(alignment: .top, spacing: 5) {
                                Text("•").font(.caption2).foregroundStyle(.secondary)
                                Text(step.instructions).font(.caption2)
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer()
                                Text(step.formattedDistance)
                                    .font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.top, 4)
                } label: {
                    Text("Directions").font(.caption2.weight(.medium))
                }
                .font(.caption2)
            }
        }
    }

    // MARK: - Completed banner

    private var completedBanner: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            Text("Route completed").font(.caption.weight(.medium))
            Spacer()
            Button("Done") { routeVM.stopSimulation(appVM: appVM) }
                .buttonStyle(.bordered).controlSize(.small)
        }
        .padding(8)
        .background(.green.opacity(0.1), in: RoundedRectangle(cornerRadius: 7))
    }

    // MARK: - Helpers

    private func formatSeconds(_ s: Double) -> String {
        let m = Int(max(0, s) / 60)
        return m < 60 ? "\(m) min" : "\(m / 60)h \(m % 60)min"
    }
}
