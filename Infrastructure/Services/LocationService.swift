import Foundation
import CoreLocation
import MapKit

// MARK: - Location Data

struct TransactionLocation: Equatable {
    let latitude: Double
    let longitude: Double
    let name: String?
    let address: String?

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    static func == (lhs: TransactionLocation, rhs: TransactionLocation) -> Bool {
        lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
    }
}

// MARK: - Location Error

enum LocationError: Error, LocalizedError {
    case permissionDenied
    case permissionRestricted
    case locationUnavailable
    case geocodingFailed
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return String(localized: "location.error.permission_denied")
        case .permissionRestricted:
            return String(localized: "location.error.permission_restricted")
        case .locationUnavailable:
            return String(localized: "location.error.unavailable")
        case .geocodingFailed:
            return String(localized: "location.error.geocoding_failed")
        case .unknown(let error):
            return error.localizedDescription
        }
    }
}

// MARK: - Location Service

@MainActor
final class LocationService: NSObject, ObservableObject {
    static let shared = LocationService()

    @Published var currentLocation: TransactionLocation?
    @Published var isLoading: Bool = false
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var searchResults: [MKMapItem] = []

    private let locationManager = CLLocationManager()
    private let geocoder = CLGeocoder()
    private var locationContinuation: CheckedContinuation<CLLocation, Error>?
    private var isLocationRequestInProgress = false

    override private init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        authorizationStatus = locationManager.authorizationStatus
    }

    // MARK: - Permission

    var hasPermission: Bool {
        switch authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            return true
        default:
            return false
        }
    }

    var canRequestPermission: Bool {
        authorizationStatus == .notDetermined
    }

    func requestPermission() {
        locationManager.requestWhenInUseAuthorization()
    }

    // MARK: - Get Current Location

    func getCurrentLocation() async -> Result<TransactionLocation, LocationError> {
        guard hasPermission else {
            if canRequestPermission {
                requestPermission()
                return .failure(.permissionDenied)
            }
            return .failure(.permissionDenied)
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let location = try await requestLocation()
            let transactionLocation = try await reverseGeocode(location: location)
            currentLocation = transactionLocation
            return .success(transactionLocation)
        } catch let error as LocationError {
            return .failure(error)
        } catch {
            return .failure(.unknown(error))
        }
    }

    private func requestLocation() async throws -> CLLocation {
        // Prevent multiple simultaneous location requests
        guard !isLocationRequestInProgress else {
            throw LocationError.locationUnavailable
        }

        isLocationRequestInProgress = true
        defer { isLocationRequestInProgress = false }

        return try await withCheckedThrowingContinuation { continuation in
            self.locationContinuation = continuation
            locationManager.requestLocation()
        }
    }

    private func reverseGeocode(location: CLLocation) async throws -> TransactionLocation {
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            guard let placemark = placemarks.first else {
                throw LocationError.geocodingFailed
            }

            let name = placemark.name ?? placemark.locality
            let address = [
                placemark.thoroughfare,
                placemark.subThoroughfare,
                placemark.locality,
                placemark.administrativeArea
            ].compactMap { $0 }.joined(separator: " ")

            return TransactionLocation(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                name: name,
                address: address.isEmpty ? nil : address
            )
        } catch {
            throw LocationError.geocodingFailed
        }
    }

    // MARK: - Search Location

    func searchLocations(query: String) async -> [MKMapItem] {
        guard !query.isEmpty else {
            searchResults = []
            return []
        }

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.resultTypes = [.pointOfInterest, .address]

        // If we have current location, search nearby
        if let current = currentLocation {
            let region = MKCoordinateRegion(
                center: current.coordinate,
                latitudinalMeters: 10000,
                longitudinalMeters: 10000
            )
            request.region = region
        }

        do {
            let search = MKLocalSearch(request: request)
            let response = try await search.start()
            searchResults = response.mapItems
            return response.mapItems
        } catch {
            searchResults = []
            return []
        }
    }

    func locationFromMapItem(_ mapItem: MKMapItem) -> TransactionLocation {
        TransactionLocation(
            latitude: mapItem.placemark.coordinate.latitude,
            longitude: mapItem.placemark.coordinate.longitude,
            name: mapItem.name,
            address: mapItem.placemark.title
        )
    }

    // MARK: - Clear

    func clearCurrentLocation() {
        currentLocation = nil
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationService: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        Task { @MainActor in
            self.authorizationStatus = status
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            // Only resume if continuation exists (prevents double resume)
            if let continuation = self.locationContinuation {
                self.locationContinuation = nil
                continuation.resume(returning: location)
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            // Only resume if continuation exists (prevents double resume)
            if let continuation = self.locationContinuation {
                self.locationContinuation = nil
                continuation.resume(throwing: LocationError.locationUnavailable)
            }
        }
    }
}
