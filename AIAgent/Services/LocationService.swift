import CoreLocation
import Foundation

final class LocationService: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var locationContinuation: CheckedContinuation<CLLocation?, Never>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    // MARK: - Authorization

    func requestAccess() -> LocationConnectionStatus {
        let status = manager.authorizationStatus
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            return .connected
        case .denied, .restricted:
            return .denied
        default:
            manager.requestWhenInUseAuthorization()
            return .notConnected
        }
    }

    func authorizationStatus() -> LocationConnectionStatus {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways: return .connected
        case .denied, .restricted: return .denied
        default: return .notConnected
        }
    }

    // MARK: - Current Area

    func getCurrentArea() async -> String? {
        let location = await requestSingleLocation()
        guard let location else { return nil }

        let geocoder = CLGeocoder()
        guard let placemarks = try? await geocoder.reverseGeocodeLocation(location),
              let placemark = placemarks.first else { return nil }

        let parts = [placemark.subLocality, placemark.locality].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }

    func formattedLocation() async -> String {
        guard authorizationStatus() == .connected else { return "" }
        guard let area = await getCurrentArea() else { return "" }
        return "Current location: \(area)"
    }

    // MARK: - Single Location Request

    private func requestSingleLocation() async -> CLLocation? {
        guard authorizationStatus() == .connected else { return nil }

        return await withCheckedContinuation { continuation in
            locationContinuation = continuation
            manager.requestLocation()
        }
    }

    // MARK: - CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        locationContinuation?.resume(returning: locations.first)
        locationContinuation = nil
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        locationContinuation?.resume(returning: nil)
        locationContinuation = nil
    }
}
