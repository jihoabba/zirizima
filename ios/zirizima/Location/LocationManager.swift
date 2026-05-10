import CoreLocation
import Combine

/// Thin CLLocationManager wrapper. Publishes `location` and `permission` for
/// SwiftUI views to react to.
@MainActor
final class LocationManager: NSObject, ObservableObject {
    static let shared = LocationManager()

    @Published var permission: CLAuthorizationStatus
    @Published var location: CLLocation?

    /// Default location used until the user grants permission. Gyeongbokgung area.
    static let defaultCoordinate = CLLocationCoordinate2D(latitude: 37.5759, longitude: 126.9737)

    private let manager = CLLocationManager()

    override init() {
        self.permission = CLLocationManager().authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.distanceFilter = 50
    }

    func requestWhenInUse() {
        manager.requestWhenInUseAuthorization()
    }

    func start() {
        manager.startUpdatingLocation()
    }
}

extension LocationManager: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        Task { @MainActor in
            self.permission = status
            if status == .authorizedWhenInUse || status == .authorizedAlways {
                manager.startUpdatingLocation()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let last = locations.last else { return }
        Task { @MainActor in
            self.location = last
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Silent — fall back to default coordinate
    }
}
