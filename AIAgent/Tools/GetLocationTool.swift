import Foundation
import CoreLocation

struct GetLocationTool: AgentTool {
    let name = "get_location"
    let description = "Get the user's current city and coordinates using device location."

    let parameters: [[String: Any]] = []

    func execute(arguments: [String: Any], context: ToolContext) async throws -> ToolResult {
        let location = try await LocationFetcher.fetchCurrentLocation()
        let placemarks = try await CLGeocoder().reverseGeocodeLocation(location)

        var parts: [String] = []
        if let placemark = placemarks.first {
            if let city = placemark.locality {
                parts.append("City: \(city)")
            }
            if let country = placemark.country {
                parts.append("Country: \(country)")
            }
        }
        parts.append(String(format: "Coordinates: %.4f, %.4f", location.coordinate.latitude, location.coordinate.longitude))

        let output = parts.joined(separator: "\n")
        return ToolResult(output: output, chatSummary: "Got location")
    }
}

// MARK: - One-shot location fetcher

private final class LocationFetcher: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocation, Error>?

    static func fetchCurrentLocation() async throws -> CLLocation {
        let fetcher = LocationFetcher()
        return try await fetcher.fetch()
    }

    private func fetch() async throws -> CLLocation {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            manager.delegate = self
            manager.desiredAccuracy = kCLLocationAccuracyHundredMeters

            let status = manager.authorizationStatus
            if status == .notDetermined {
                manager.requestWhenInUseAuthorization()
            } else if status == .denied || status == .restricted {
                continuation.resume(throwing: NSError(
                    domain: "Location",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "Location access denied. Ask the user to enable it in Settings."]
                ))
                self.continuation = nil
            } else {
                manager.requestLocation()
            }
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard continuation != nil else { return }
        let status = manager.authorizationStatus
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            manager.requestLocation()
        } else if status == .denied || status == .restricted {
            continuation?.resume(throwing: NSError(
                domain: "Location",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Location access denied."]
            ))
            continuation = nil
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.first else { return }
        continuation?.resume(returning: location)
        continuation = nil
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        continuation?.resume(throwing: error)
        continuation = nil
    }
}
