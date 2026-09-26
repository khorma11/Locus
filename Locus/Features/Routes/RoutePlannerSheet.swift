import CoreLocation
import SwiftUI

struct RoutePlannerSheet: View {
    @Binding var start: CLLocationCoordinate2D?
    @Binding var end: CLLocationCoordinate2D?
    @Binding var routeOptions: [RoadRouteOption]
    @Binding var selectedRouteID: RoadRouteOption.ID?
    @Binding var isRouting: Bool
    var onBuild: () -> Void
    var onSelectRoute: (RoadRouteOption) -> Void
    var onPlay: () -> Void
    var onPickStart: () -> Void
    var onPickEnd: () -> Void
    var onImportGPX: () -> Void
    var onExportGPX: () -> Void
    var onUseDrawn: () -> Void
    var onGPXRoute: (GPXRouteFile, GPXRouteAction) -> Void

    @EnvironmentObject private var session: SpoofSession
    @Environment(\.dismiss) private var dismiss
    @State private var savedRoutes = SavedRoute.load()
    @State private var routeName = ""
    @State private var isNamingRoute = false
    @State private var gpxRoutes: [GPXRouteFile] = []
    @State private var routePendingDeletion: GPXRouteFile?

    var body: some View {
        NavigationStack {
            List {
                Section("Movement Speed") {
                    HStack {
                        Label("Route speed", systemImage: "speedometer")
                        Spacer()
                        Text("\(Int(session.routeSpeedKPH.rounded())) km/h")
                            .font(.headline.monospacedDigit())
                            .foregroundStyle(LocusTheme.accent)
                    }

                    Slider(value: $session.routeSpeedKPH, in: 3...160, step: 1) {
                        Text("Route speed")
                    } minimumValueLabel: {
                        Text("3")
                            .font(.caption2)
                    } maximumValueLabel: {
                        Text("160")
                            .font(.caption2)
                    }

                    HStack {
                        ForEach([5.0, 15.0, 40.0, 80.0, 120.0], id: \.self) { speed in
                            Button("\(Int(speed))") {
                                session.routeSpeedKPH = speed
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }

                    Text("Speed can be changed while a route is moving. Selecting Walk, Run, Cycle, or Drive resets it to that mode's normal speed.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("GPX Route Library") {
                    if gpxRoutes.isEmpty {
                        ContentUnavailableView(
                            "No GPX Routes",
                            systemImage: "map",
                            description: Text("Import a GPX file to keep it in this library.")
                        )
                    } else {
                        ForEach(gpxRoutes) { route in
                            VStack(alignment: .leading, spacing: 10) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(route.name)
                                        .font(.subheadline.weight(.semibold))
                                    Text(route.detail)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                HStack(spacing: 16) {
                                    routeButton("Preview", icon: "eye") {
                                        onGPXRoute(route, .preview)
                                    }
                                    routeButton("Start", icon: "play.fill") {
                                        onGPXRoute(route, .start)
                                    }
                                    Menu {
                                        Button {
                                            onGPXRoute(route, .reverse)
                                        } label: {
                                            Label("Start Reverse", systemImage: "arrow.uturn.backward")
                                        }
                                        Button {
                                            onGPXRoute(route, .loop)
                                        } label: {
                                            Label("Loop Continuously", systemImage: "repeat")
                                        }
                                        Divider()
                                        Button(role: .destructive) {
                                            routePendingDeletion = route
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    } label: {
                                        Label("More", systemImage: "ellipsis.circle")
                                            .font(.caption.weight(.semibold))
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }

                    Button(action: onImportGPX) {
                        Label("Import GPX", systemImage: "square.and.arrow.down")
                    }
                }

                Section("Saved routes") {
                    ForEach(savedRoutes) { route in
                        Button {
                            start = route.start ?? session.simulated ?? session.pin
                            end = route.end
                            routeOptions.removeAll()
                            selectedRouteID = nil
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
                    HStack(spacing: 10) {
                        Button {
                            onPickStart()
                        } label: {
                            Label("Pick Start", systemImage: "smallcircle.filled.circle")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)

                        Button {
                            onPickEnd()
                        } label: {
                            Label("Pick End", systemImage: "mappin.circle.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                    }

                    Button("Use current pin / spoof as start") {
                        start = session.simulated ?? session.pin
                        routeOptions.removeAll()
                        selectedRouteID = nil
                    }
                    Button("Use current pin as end") {
                        end = session.pin
                        routeOptions.removeAll()
                        selectedRouteID = nil
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
                            Label("Build route", systemImage: "road.lanes")
                        }
                    }
                    .disabled(isRouting)
                }

                if !routeOptions.isEmpty {
                    Section("Route options") {
                        ForEach(routeOptions) { option in
                            Button {
                                onSelectRoute(option)
                            } label: {
                                HStack(alignment: .center, spacing: 12) {
                                    Image(systemName: selectedRouteID == option.id ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(selectedRouteID == option.id ? LocusTheme.accent : .secondary)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(option.name)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(.primary)
                                        Text("\(option.durationText) · \(option.distanceText)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer(minLength: 0)
                                    Label("Preview", systemImage: "eye")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(LocusTheme.accent)
                                        .labelStyle(.iconOnly)
                                        .accessibilityLabel("Preview route")
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
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
                    Button(action: onExportGPX) {
                        Label("Export GPX", systemImage: "square.and.arrow.up")
                    }
                }

                Section {
                    Text("Locus tries Apple Maps roads/footpaths first. If no road route is found, it creates a direct route between the pins. Import GPX for exact roads.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Routes")
            .onAppear { reloadGPXRoutes() }
            .alert("Save Route", isPresented: $isNamingRoute) {
                TextField("Route name", text: $routeName)
                Button("Cancel", role: .cancel) {}
                Button("Save") { saveCurrentRoute() }
            } message: {
                Text("This route will remain available in Locus.")
            }
            .confirmationDialog(
                "Delete \(routePendingDeletion?.name ?? "route")?",
                isPresented: Binding(
                    get: { routePendingDeletion != nil },
                    set: { if !$0 { routePendingDeletion = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Delete GPX", role: .destructive) {
                    deletePendingRoute()
                }
                Button("Cancel", role: .cancel) {
                    routePendingDeletion = nil
                }
            } message: {
                Text("This removes the file from Locus Documents.")
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .sessionErrorAlert()
    }

    private func coordText(_ c: CLLocationCoordinate2D?) -> String {
        guard let c else { return "—" }
        return String(format: "%.5f, %.5f", c.latitude, c.longitude)
    }

    private func routeButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.caption.weight(.semibold))
        }
        .buttonStyle(.borderless)
    }

    private func reloadGPXRoutes() {
        gpxRoutes = GPXRouteFile.loadAll()
    }

    private func deletePendingRoute() {
        guard let route = routePendingDeletion else { return }
        do {
            try route.delete()
            routePendingDeletion = nil
            reloadGPXRoutes()
        } catch {
            routePendingDeletion = nil
            session.lastError = error.localizedDescription
        }
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
