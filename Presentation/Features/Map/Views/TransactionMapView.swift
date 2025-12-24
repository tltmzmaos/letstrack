import SwiftUI
import SwiftData
import MapKit

struct TransactionMapView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var transactionsWithLocation: [Transaction] = []
    @State private var mapAnnotations: [TransactionMapAnnotation] = []
    @State private var selectedTransaction: Transaction?
    @State private var mapPosition: MapCameraPosition = .automatic
    @State private var showTransactionDetail: Bool = false

    var body: some View {
        NavigationStack {
            ZStack {
                if mapAnnotations.isEmpty {
                    emptyStateView
                } else {
                    mapView
                }
            }
            .navigationTitle(String(localized: "map.title"))
            .sheet(isPresented: $showTransactionDetail) {
                if let transaction = selectedTransaction {
                    TransactionDetailView(transaction: transaction)
                }
            }
            .onAppear {
                Task { await loadTransactionsWithLocation() }
            }
        }
    }

    private func loadTransactionsWithLocation() async {
        // Fetch only transactions that have location data
        var descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate<Transaction> { $0.latitude != nil && $0.longitude != nil },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = 500 // Limit for performance

        do {
            let preloader = AppDataPreloader.shared
            if !preloader.transactions.isEmpty {
                transactionsWithLocation = preloader.transactions
                    .filter { $0.latitude != nil && $0.longitude != nil }
                    .prefix(500)
                    .map { $0 }
            } else {
                transactionsWithLocation = try modelContext.fetch(descriptor)
            }
            mapAnnotations = transactionsWithLocation.compactMap { transaction in
                guard let lat = transaction.latitude, let lon = transaction.longitude else { return nil }
                return TransactionMapAnnotation(
                    id: transaction.id,
                    transaction: transaction,
                    coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                    title: transaction.locationName ?? transaction.category?.name ?? ""
                )
            }
        } catch {
            transactionsWithLocation = []
            mapAnnotations = []
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "map")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                Text(String(localized: "map.empty.title"))
                    .font(.headline)

                Text(String(localized: "map.empty.description"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }

    private var mapView: some View {
        Map(position: $mapPosition, selection: $selectedTransaction) {
            ForEach(mapAnnotations) { annotation in
                Annotation(
                    annotation.title,
                    coordinate: annotation.coordinate,
                    anchor: .bottom
                ) {
                    TransactionMapPin(
                        transaction: annotation.transaction,
                        isSelected: selectedTransaction?.id == annotation.transaction.id
                    )
                }
                .tag(annotation.transaction)
            }
        }
        .mapStyle(.standard(pointsOfInterest: .all))
        .mapControls {
            MapUserLocationButton()
            MapCompass()
            MapScaleView()
        }
        .overlay(alignment: .bottom) {
            if let transaction = selectedTransaction {
                TransactionMapCard(transaction: transaction) {
                    showTransactionDetail = true
                }
                .padding()
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedTransaction?.id)
        .onAppear {
            fitToTransactions()
        }
    }

    private func fitToTransactions() {
        guard !mapAnnotations.isEmpty else { return }

        // Single pass to compute min/max coordinates
        var minLat = Double.greatestFiniteMagnitude
        var maxLat = -Double.greatestFiniteMagnitude
        var minLon = Double.greatestFiniteMagnitude
        var maxLon = -Double.greatestFiniteMagnitude
        var hasValidCoordinate = false

        for annotation in mapAnnotations {
            hasValidCoordinate = true
            minLat = min(minLat, annotation.coordinate.latitude)
            maxLat = max(maxLat, annotation.coordinate.latitude)
            minLon = min(minLon, annotation.coordinate.longitude)
            maxLon = max(maxLon, annotation.coordinate.longitude)
        }

        guard hasValidCoordinate else { return }

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )

        let span = MKCoordinateSpan(
            latitudeDelta: max((maxLat - minLat) * 1.5, 0.01),
            longitudeDelta: max((maxLon - minLon) * 1.5, 0.01)
        )

        let region = MKCoordinateRegion(center: center, span: span)
        mapPosition = .region(region)
    }
}

// MARK: - Transaction Map Pin

struct TransactionMapPin: View {
    let transaction: Transaction
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Circle()
                    .fill(pinColor)
                    .frame(width: isSelected ? 44 : 36, height: isSelected ? 44 : 36)
                    .shadow(color: pinColor.opacity(0.4), radius: isSelected ? 8 : 4)

                if let category = transaction.category {
                    Image(systemName: category.icon)
                        .font(isSelected ? .body : .caption)
                        .foregroundStyle(.white)
                } else {
                    Image(systemName: transaction.type == .income ? "arrow.down" : "arrow.up")
                        .font(isSelected ? .body : .caption)
                        .foregroundStyle(.white)
                }
            }

            // Pin tail
            Triangle()
                .fill(pinColor)
                .frame(width: 12, height: 8)
                .offset(y: -2)
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
    }

    private var pinColor: Color {
        if let category = transaction.category {
            return category.color
        }
        return transaction.type == .income ? .green : .red
    }
}

private struct TransactionMapAnnotation: Identifiable {
    let id: UUID
    let transaction: Transaction
    let coordinate: CLLocationCoordinate2D
    let title: String
}

// MARK: - Triangle Shape

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Transaction Map Card

struct TransactionMapCard: View {
    let transaction: Transaction
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Category icon
                if let category = transaction.category {
                    Image(systemName: category.icon)
                        .font(.title3)
                        .foregroundStyle(category.color)
                        .frame(width: 44, height: 44)
                        .background(category.color.opacity(0.15))
                        .clipShape(Circle())
                } else {
                    Image(systemName: "questionmark.circle")
                        .font(.title3)
                        .foregroundStyle(.gray)
                        .frame(width: 44, height: 44)
                        .background(Color.gray.opacity(0.15))
                        .clipShape(Circle())
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(transaction.category?.name ?? String(localized: "categories.uncategorized"))
                            .font(.subheadline.weight(.semibold))

                        Spacer()

                        Text(transaction.formattedSignedAmount)
                            .font(.subheadline.bold())
                            .foregroundStyle(transaction.type == .income ? .green : .primary)
                    }

                    HStack {
                        if let locationName = transaction.locationName {
                            HStack(spacing: 4) {
                                Image(systemName: "mappin")
                                    .font(.caption2)
                                Text(locationName)
                                    .lineLimit(1)
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Text(transaction.date.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if !transaction.note.isEmpty {
                        Text(transaction.note)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    TransactionMapView()
        .modelContainer(for: [Transaction.self, Category.self], inMemory: true)
}
