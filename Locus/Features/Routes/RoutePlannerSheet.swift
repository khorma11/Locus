import CoreLocation
import SwiftUI

struct RoutePlannerSheet: View {
    @Binding var start: CLLocationCoordinate2D?
    @Binding var end: CLLocationCoordinate2D?
    @Binding var isRouting: Bool
    var onBuild: () -> Void
    var onPlay: () -> Void
    var onImportGPX: () -> Void
    var onExportGPX: () -> Void
    var onUseDrawn: () -> Void

    @EnvironmentObject private var session: SpoofSession
    @Environment(\.dismiss) private var dismiss
    @State private var savedRoutes = SavedRoute.load()
    @State private var routeName = ""
    @State private var isNamingRoute = false

    var body: some View {
        NavigationStack {
            List {
                Section("Saved routes") {
                    ForEach(savedRoutes) { route in
                        Button {
                            start = route.start ?? session.simulated ?? session.pin
                            end = route.end
                        } label: {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(route.name)
                                Text(route.start == nil ? "Current pin → saved destination" : "Saved start → saved destination")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .onDelete { offsets in
                        savedRoutes.remove(atOffsets: offsets)
                        SavedRoute.save(savedRoutes)
                    }

                    Button {
                        routeName = "Saved Route \(savedRoutes.count + 1)"
                        isNamingRoute = true
                    } label: {
                        Label("Save current start and end", systemImage: "bookmark")
                    }
                    .disabled(end == nil)
                }

                Section("Road route") {
                    Button("Use current pin / spoof as start") {
                        start = session.simulated ?? session.pin
                    }
                    Button("Use current pin as end") {
                        end = session.pin
                    }
                    LabeledContent("Start") {
                        Text(coordText(start)).font(.caption.monospaced())
                    }
                    LabeledContent("End") {
                        Text(coordText(end)).font(.caption.monospaced())
                    }
                    Button {
                        onBuild()
                    } label: {
                        if isRouting {
                            ProgressView()
                        } else {
                            Label("Build walk/drive route on roads", systemImage: "road.lanes")
                        }
                    }
                    .disabled(isRouting)
                }

                Section("Play / draw / GPX") {
                    Button {
                        onUseDrawn()
                    } label: {
                        Label("Use drawn path from map", systemImage: "pencil.tip")
                    }
                    Button(action: onPlay) {
                        Label("Follow route", systemImage: "play.fill")
                    }
                    Button(action: onImportGPX) {
                        Label("Import GPX", systemImage: "square.and.arrow.down")
                    }
                    Button(action: onExportGPX) {
                        Label("Export GPX", systemImage: "square.and.arrow.up")
                    }
                }

                Section {
                    Text("Routes follow Apple Maps roads/footpaths for the selected travel mode. Speed gets light random variation so motion looks less robotic.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Routes")
            .alert("Save Route", isPresented: $isNamingRoute) {
                TextField("Route name", text: $routeName)
                Button("Cancel", role: .cancel) {}
                Button("Save") { saveCurrentRoute() }
            } message: {
                Text("This route will remain available in Locus.")
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func coordText(_ c: CLLocationCoordinate2D?) -> String {
        guard let c else { return "—" }
        return String(format: "%.5f, %.5f", c.latitude, c.longitude)
    }

    private func saveCurrentRoute() {
        guard let end else { return }
        let trimmedName = routeName.trimmingCharacters(in: .whitespacesAndNewlines)
        let route = SavedRoute(
            id: UUID(),
            name: trimmedName.isEmpty ? "Saved Route" : trimmedName,
            startLatitude: start?.latitude,
            startLongitude: start?.longitude,
            endLatitude: end.latitude,
            endLongitude: end.longitude
        )
        savedRoutes.append(route)
        SavedRoute.save(savedRoutes)
    }
}
