import SwiftUI
import MapKit

struct LocationPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var locationService = LocationService.shared
    @Binding var selectedLocation: TransactionLocation?

    @State private var searchText: String = ""
    @State private var searchTask: Task<Void, Never>?
    @State private var mapPosition: MapCameraPosition = .automatic
    @State private var selectedMapItem: MKMapItem?
    @State private var showLocationError: Bool = false
    @State private var locationErrorMessage: String = ""
    @State private var pendingCurrentLocationRequest: Bool = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)

                    TextField(String(localized: "location.search_placeholder"), text: $searchText)
                        .textFieldStyle(.plain)
                        .autocorrectionDisabled()

                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                            locationService.searchResults = []
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(12)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding()

                // Current location button
                Button {
                    if locationService.canRequestPermission {
                        locationService.requestPermission()
                        pendingCurrentLocationRequest = true
                    } else if locationService.hasPermission {
                        Task {
                            let result = await locationService.getCurrentLocation()
                            switch result {
                            case .success(let location):
                                selectedLocation = location
                                dismiss()
                            case .failure(let error):
                                locationErrorMessage = error.localizedDescription
                                showLocationError = true
                            }
                        }
                    } else {
                        locationErrorMessage = String(localized: "location.error.permission_denied")
                        showLocationError = true
                    }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "location.fill")
                            .font(.body)
                            .foregroundStyle(.blue)
                            .frame(width: 36, height: 36)
                            .background(Color.blue.opacity(0.1))
                            .clipShape(Circle())

                        VStack(alignment: .leading, spacing: 2) {
                            Text(String(localized: "location.current"))
                                .font(.subheadline.weight(.medium))

                            if !locationService.hasPermission && !locationService.canRequestPermission {
                                Text(String(localized: "location.permission_required"))
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            } else {
                                Text(String(localized: "location.use_current_location"))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Spacer()

                        if locationService.isLoading {
                            ProgressView()
                        } else {
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.plain)
                .disabled(locationService.isLoading)

                Divider()
                    .padding(.horizontal)

                // Search results or map
                if locationService.searchResults.isEmpty && searchText.isEmpty {
                    // Show map for manual selection
                    Map(position: $mapPosition, selection: $selectedMapItem) {
                        if let location = locationService.currentLocation {
                            Marker(String(localized: "location.current"), coordinate: location.coordinate)
                                .tint(.blue)
                        }
                    }
                    .mapStyle(.standard(pointsOfInterest: .all))
                    .mapControls {
                        MapUserLocationButton()
                        MapCompass()
                    }
                    .overlay(alignment: .bottom) {
                        if selectedMapItem != nil {
                            Button {
                                if let item = selectedMapItem {
                                    selectedLocation = locationService.locationFromMapItem(item)
                                    dismiss()
                                }
                            } label: {
                                Text(String(localized: "location.select_this"))
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.accentColor)
                                    .foregroundStyle(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                            .padding()
                        }
                    }
                } else {
                    // Search results list
                    List {
                        ForEach(locationService.searchResults, id: \.self) { mapItem in
                            Button {
                                selectedLocation = locationService.locationFromMapItem(mapItem)
                                dismiss()
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "mappin.circle.fill")
                                        .font(.title2)
                                        .foregroundStyle(.red)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(mapItem.name ?? String(localized: "location.unknown"))
                                            .font(.subheadline.weight(.medium))
                                            .foregroundStyle(.primary)

                                        if let address = mapItem.placemark.title {
                                            Text(address)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                                .lineLimit(1)
                                        }
                                    }

                                    Spacer()
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle(String(localized: "location.select"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "common.cancel")) {
                        dismiss()
                    }
                }
            }
            .onChange(of: searchText) { _, newValue in
                searchTask?.cancel()

                // Skip debounce for empty search (immediate clear)
                if newValue.isEmpty {
                    locationService.searchResults = []
                    return
                }

                searchTask = Task {
                    try? await Task.sleep(nanoseconds: 300_000_000) // 300ms debounce
                    guard !Task.isCancelled else { return }
                    _ = await locationService.searchLocations(query: newValue)
                }
            }
            .onChange(of: locationService.authorizationStatus) { _, newValue in
                guard pendingCurrentLocationRequest else { return }
                if newValue == .authorizedWhenInUse || newValue == .authorizedAlways {
                    pendingCurrentLocationRequest = false
                    Task {
                        let result = await locationService.getCurrentLocation()
                        switch result {
                        case .success(let location):
                            selectedLocation = location
                            dismiss()
                        case .failure(let error):
                            locationErrorMessage = error.localizedDescription
                            showLocationError = true
                        }
                    }
                } else if newValue == .denied || newValue == .restricted {
                    pendingCurrentLocationRequest = false
                    locationErrorMessage = String(localized: "location.error.permission_denied")
                    showLocationError = true
                }
            }
            .onAppear {
                // Try to get current location for better search results
                if locationService.hasPermission && locationService.currentLocation == nil {
                    Task {
                        _ = await locationService.getCurrentLocation()
                    }
                }
            }
            .alert(String(localized: "location.error.title"), isPresented: $showLocationError) {
                Button(String(localized: "common.ok"), role: .cancel) {}
            } message: {
                Text(locationErrorMessage)
            }
        }
    }
}

#Preview {
    LocationPickerView(selectedLocation: .constant(nil))
}
