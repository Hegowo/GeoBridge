import SwiftUI

struct CoordinateInputView: View {
    @ObservedObject var appVM: AppViewModel

    @State private var latText: String = ""
    @State private var lonText: String = ""
    @State private var validationError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Manual Coordinates", systemImage: "scope")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                coordinateField(placeholder: "Latitude", text: $latText, range: -90...90)
                coordinateField(placeholder: "Longitude", text: $lonText, range: -180...180)
                applyButton
            }

            if let error = validationError {
                Text(error).font(.caption).foregroundStyle(.red)
            } else if let coord = appVM.selectedCoordinate {
                HStack(spacing: 4) {
                    Image(systemName: "location.fill")
                        .font(.caption2)
                        .foregroundStyle(.blue)
                    Text(coord.formatted)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button {
                        appVM.copyCoordinates()
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .help("Copy coordinates")
                }
            }
        }
        .onChange(of: appVM.selectedCoordinate) { _, coord in
            if let c = coord {
                latText = String(format: "%.6f", c.latitude)
                lonText = String(format: "%.6f", c.longitude)
            }
        }
    }

    private func coordinateField(placeholder: String, text: Binding<String>, range: ClosedRange<Double>) -> some View {
        TextField(placeholder, text: text)
            .textFieldStyle(.plain)
            .multilineTextAlignment(.center)
            .font(.system(.callout, design: .monospaced))
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(.quinary, in: RoundedRectangle(cornerRadius: 6))
            .frame(maxWidth: .infinity)
    }

    private var applyButton: some View {
        Button("Apply") {
            applyManualCoordinates()
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .disabled(latText.isEmpty || lonText.isEmpty)
    }

    private func applyManualCoordinates() {
        validationError = nil
        guard let lat = Double(latText) else {
            validationError = "Invalid latitude"
            return
        }
        guard let lon = Double(lonText) else {
            validationError = "Invalid longitude"
            return
        }
        guard lat >= -90 && lat <= 90 else {
            validationError = "Latitude must be between -90 and 90"
            return
        }
        guard lon >= -180 && lon <= 180 else {
            validationError = "Longitude must be between -180 and 180"
            return
        }
        appVM.setSelectedCoordinate(latitude: lat, longitude: lon)
    }
}
