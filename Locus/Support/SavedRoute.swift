import CoreLocation
import Foundation

struct SavedRoute: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var startLatitude: Double?
    var startLongitude: Double?
    var endLatitude: Double
    var endLongitude: Double

    var start: CLLocationCoordinate2D? {
        guard let startLatitude, let startLongitude else { return nil }
        return CLLocationCoordinate2D(latitude: startLatitude, longitude: startLongitude)
    }

    var end: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: endLatitude, longitude: endLongitude)
    }

    static let shahdaraTownPoliceStation = SavedRoute(
        id: UUID(uuidString: "A310F459-E69A-4D43-B593-C257535A75DA")!,
        name: "PS Shahdara Town",
        startLatitude: nil,
        startLongitude: nil,
        endLatitude: 31.620585,
        endLongitude: 74.289179
    )

    private static let defaultsKey = "locus.savedRoutes"

    static func load() -> [SavedRoute] {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let routes = try? JSONDecoder().decode([SavedRoute].self, from: data) else {
            let routes = [shahdaraTownPoliceStation]
            save(routes)
            return routes
        }
        return routes
    }

    static func save(_ routes: [SavedRoute]) {
        guard let data = try? JSONEncoder().encode(routes) else { return }
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }
}
