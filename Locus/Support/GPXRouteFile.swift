import CoreLocation
import Foundation

enum GPXRouteAction {
    case preview
    case start
    case reverse
    case loop
}

struct GPXRouteFile: Identifiable, Equatable {
    let url: URL
    let pointCount: Int
    let distanceMeters: CLLocationDistance
    let modifiedAt: Date?

    var id: String { url.path }

    var name: String {
        url.deletingPathExtension().lastPathComponent
            .replacingOccurrences(of: "-", with: " ")
    }

    var detail: String {
        let distance = Measurement(value: distanceMeters / 1000, unit: UnitLength.kilometers)
        let formatted = distance.formatted(.measurement(width: .abbreviated, usage: .road))
        return "\(pointCount) points • \(formatted)"
    }

    static func loadAll() -> [GPXRouteFile] {
        guard let directory = documentsDirectory else { return [] }
        let keys: Set<URLResourceKey> = [.contentModificationDateKey, .isRegularFileKey]
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles]
        ) else { return [] }

        return urls.compactMap { url in
            guard url.pathExtension.lowercased() == "gpx",
                  let values = try? url.resourceValues(forKeys: keys),
                  values.isRegularFile == true,
                  let coordinates = try? GPXCodec.parse(url),
                  coordinates.count >= 2 else { return nil }
            return GPXRouteFile(
                url: url,
                pointCount: coordinates.count,
                distanceMeters: routeDistance(coordinates),
                modifiedAt: values.contentModificationDate
            )
        }
        .sorted {
            if $0.modifiedAt != $1.modifiedAt {
                return ($0.modifiedAt ?? .distantPast) > ($1.modifiedAt ?? .distantPast)
            }
            return $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
    }

    static func importFile(from source: URL) throws -> URL {
        guard let directory = documentsDirectory else {
            throw CocoaError(.fileNoSuchFile)
        }
        let accessing = source.startAccessingSecurityScopedResource()
        defer { if accessing { source.stopAccessingSecurityScopedResource() } }

        let sourceURL = source.standardizedFileURL
        if sourceURL.deletingLastPathComponent() == directory.standardizedFileURL {
            return sourceURL
        }

        let fileManager = FileManager.default
        let incoming = try Data(contentsOf: source)
        let baseName = source.deletingPathExtension().lastPathComponent
        let fileExtension = source.pathExtension.isEmpty ? "gpx" : source.pathExtension
        var destination = directory.appendingPathComponent("\(baseName).\(fileExtension)")
        var suffix = 2
        while fileManager.fileExists(atPath: destination.path) {
            let existing = try Data(contentsOf: destination)
            if existing == incoming { return destination }
            destination = directory.appendingPathComponent("\(baseName) \(suffix).\(fileExtension)")
            suffix += 1
        }
        try fileManager.copyItem(at: source, to: destination)
        return destination
    }

    func delete() throws {
        try FileManager.default.removeItem(at: url)
    }

    private static var documentsDirectory: URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
    }

    private static func routeDistance(_ coordinates: [CLLocationCoordinate2D]) -> CLLocationDistance {
        zip(coordinates, coordinates.dropFirst()).reduce(0) { total, pair in
            total + CLLocation(latitude: pair.0.latitude, longitude: pair.0.longitude)
                .distance(from: CLLocation(latitude: pair.1.latitude, longitude: pair.1.longitude))
        }
    }
}
