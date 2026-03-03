import SwiftUI
import MapKit

struct SatelliteCoverageMapView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var settings: AppSettings

    @StateObject private var apiService = SatelliteAPI()
    @State private var mapType: MKMapType = .satellite
    @State private var trackedSatellite: Satellite
    @State private var isRefreshing = false
    @State private var refreshStatus: String?
    @State private var refreshTick = 0

    @Environment(\.colorScheme) private var colorScheme

    private static let statusTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        formatter.dateStyle = .none
        return formatter
    }()

    init(satellite: Satellite, settings: AppSettings) {
        self.settings = settings
        _trackedSatellite = State(initialValue: satellite)
    }

    private var coverageData: SatelliteCoverageData? {
        SatelliteCoverageData.make(from: trackedSatellite)
    }

    private var observerCoordinate: CLLocationCoordinate2D? {
        guard let lat = trackedSatellite.observerLatitude,
              let lon = trackedSatellite.observerLongitude else {
            return nil
        }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    private var autoRefreshTaskID: String {
        "\(trackedSatellite.id)-\(settings.updateMode.rawValue)-\(settings.refreshInterval)-\(refreshTick)"
    }

    var body: some View {
        NavigationView {
            ZStack {
                if let coverageData {
                    SatelliteCoverageMapRepresentable(
                        coverageData: coverageData,
                        satelliteName: trackedSatellite.name,
                        observerCoordinate: observerCoordinate,
                        mapType: mapType
                    )
                    .ignoresSafeArea()
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "map.fill")
                            .font(.system(size: 42, weight: .semibold, design: .rounded))
                            .foregroundColor(.secondary)
                        Text("Нет данных о положении спутника для построения зоны покрытия")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                }

                VStack(spacing: 12) {
                    HStack(spacing: 8) {
                        Menu {
                            Button("Схема") { mapType = .standard }
                            Button("Спутник") { mapType = .satellite }
                        } label: {
                            Label("Карта", systemImage: "map")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(UITheme.surfaceBackground(for: colorScheme))
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule().stroke(UITheme.cardBorder(for: colorScheme), lineWidth: 1)
                                )
                        }

                        Spacer()

                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)
                                .frame(width: 30, height: 30)
                                .background(UITheme.surfaceBackground(for: colorScheme))
                                .clipShape(Circle())
                                .overlay(
                                    Circle().stroke(UITheme.cardBorder(for: colorScheme), lineWidth: 1)
                                )
                        }
                    }

                    coverageInfoPanel

                    Spacer()

                    legendPanel
                }
                .padding(12)
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        .navigationViewStyle(.stack)
        .task(id: autoRefreshTaskID) {
            guard settings.updateMode == .automatic, settings.refreshInterval > 0 else { return }
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(settings.refreshInterval) * 1_000_000_000)
                await refreshPosition(force: true)
            }
        }
    }

    @MainActor
    private func refreshPosition(force: Bool) async {
        guard let observer = observerCoordinate else {
            refreshStatus = "Неизвестны координаты наблюдателя"
            return
        }

        if settings.updateMode == .disabled {
            refreshStatus = "Обновление спутников отключено в настройках"
            return
        }

        isRefreshing = true
        defer { isRefreshing = false }

        await apiService.fetchSatellites(
            apiKey: settings.apiKey,
            noradIDs: [trackedSatellite.id],
            latitude: observer.latitude,
            longitude: observer.longitude,
            altitude: 0,
            refreshInterval: settings.refreshInterval,
            forceRefresh: force,
            allowRemoteUpdates: true,
            onCacheUpdated: nil
        )

        if let updated = apiService.satellites.first(where: { $0.id == trackedSatellite.id }) {
            if !updated.isError, updated.satelliteLongitude != nil {
                trackedSatellite = updated
                refreshStatus = "Обновлено: \(timeString(from: updated.timestamp))"
                refreshTick += 1
            } else {
                refreshStatus = updated.errorMessage ?? "Ошибка обновления. Оставлены последние валидные данные."
            }
        } else if let error = apiService.errorMessage {
            refreshStatus = error
        }
    }

    private func timeString(from date: Date) -> String {
        Self.statusTimeFormatter.string(from: date)
    }

    private func formatGeoLongitude(_ value: Double?) -> String {
        guard let value else { return "N/A" }
        let direction = value >= 0 ? "E" : "W"
        return String(format: "%.1f°%@", abs(value), direction)
    }

    private var coverageInfoPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Геодолгота: \(formatGeoLongitude(trackedSatellite.satelliteLongitude))")
                    .font(.caption)
                    .fontWeight(.semibold)
                Spacer()
                Text("NORAD \(trackedSatellite.id)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 14) {
                infoChip(title: "Азимут", value: String(format: "%.0f°", trackedSatellite.azimuth), color: .blue)
                infoChip(title: "Элевация", value: String(format: "%.0f°", trackedSatellite.elevation), color: .green)
                infoChip(title: "Дистанция", value: String(format: "%.0f км", trackedSatellite.distanceKm), color: .orange)
            }

            if let refreshStatus {
                Text(refreshStatus)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .background(UITheme.surfaceBackground(for: colorScheme).opacity(0.95))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(UITheme.cardBorder(for: colorScheme), lineWidth: 1)
        )
    }

    private func infoChip(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
    }

    private var legendPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Circle().fill(Color.orange.opacity(0.35)).frame(width: 12, height: 12)
                Text("Оранжевая зона: геометрическая видимость (угол места > 0°)")
                    .font(.caption2)
            }
            HStack(spacing: 8) {
                Circle().fill(Color.green.opacity(0.35)).frame(width: 12, height: 12)
                Text("Зеленая зона: уверенный прием (угол места >= 5°)")
                    .font(.caption2)
            }
            HStack(spacing: 8) {
                Rectangle().fill(Color.cyan.opacity(0.7)).frame(width: 12, height: 2)
                Text("Линия визирования: вы -> подспутниковая точка")
                    .font(.caption2)
            }
        }
        .padding(12)
        .background(UITheme.surfaceBackground(for: colorScheme).opacity(0.95))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(UITheme.cardBorder(for: colorScheme), lineWidth: 1)
        )
    }
}

private struct SatelliteCoverageData {
    private static let minimumVisibleElevationDeg: Double = 0
    private static let minimumConfidentElevationDeg: Double = 5
    private static let maxGeometricCentralAngleDeg: Double = 81.3

    let subSatelliteCoordinate: CLLocationCoordinate2D
    let fullCoverageRadiusMeters: CLLocationDistance
    let confidentCoverageRadiusMeters: CLLocationDistance

    static func make(from satellite: Satellite) -> SatelliteCoverageData? {
        let latitude = satellite.satelliteLatitude ?? 0
        guard let longitude = satellite.satelliteLongitude else { return nil }
        let altitudeKm = satellite.satelliteAltitudeKm ?? 35_786.0

        let fullRadius = coverageRadiusMeters(
            altitudeKm: altitudeKm,
            minimumElevationDeg: minimumVisibleElevationDeg
        )
        let confidentRadius = coverageRadiusMeters(
            altitudeKm: altitudeKm,
            minimumElevationDeg: minimumConfidentElevationDeg
        )

        return SatelliteCoverageData(
            subSatelliteCoordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
            fullCoverageRadiusMeters: fullRadius,
            confidentCoverageRadiusMeters: confidentRadius
        )
    }

    private static func coverageRadiusMeters(altitudeKm: Double, minimumElevationDeg: Double) -> CLLocationDistance {
        let earthRadiusKm = 6378.137
        let ratio = earthRadiusKm / (earthRadiusKm + altitudeKm)
        let elevation = minimumElevationDeg * .pi / 180

        let clamped = max(-1.0, min(1.0, ratio * cos(elevation)))
        let geometricMax = maxGeometricCentralAngleDeg * .pi / 180
        let psi = min(geometricMax, max(0, acos(clamped) - elevation))
        return psi * earthRadiusKm * 1000
    }
}

private struct SatelliteCoverageMapRepresentable: UIViewRepresentable {
    let coverageData: SatelliteCoverageData
    let satelliteName: String
    let observerCoordinate: CLLocationCoordinate2D?
    let mapType: MKMapType

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView(frame: .zero)
        mapView.delegate = context.coordinator
        mapView.showsCompass = true
        mapView.showsScale = true
        mapView.pointOfInterestFilter = .excludingAll
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        mapView.mapType = mapType
        mapView.removeOverlays(mapView.overlays)
        mapView.removeAnnotations(mapView.annotations)

        let full = MKCircle(center: coverageData.subSatelliteCoordinate, radius: coverageData.fullCoverageRadiusMeters)
        full.title = "full"
        let confident = MKCircle(center: coverageData.subSatelliteCoordinate, radius: coverageData.confidentCoverageRadiusMeters)
        confident.title = "confident"

        var overlays: [MKOverlay] = [full, confident]

        if let observerCoordinate {
            let points = [observerCoordinate, coverageData.subSatelliteCoordinate]
            overlays.append(MKPolyline(coordinates: points, count: points.count))
        }

        mapView.addOverlays(overlays)

        let satAnnotation = MKPointAnnotation()
        satAnnotation.coordinate = coverageData.subSatelliteCoordinate
        satAnnotation.title = satelliteName
        mapView.addAnnotation(satAnnotation)

        if let observerCoordinate {
            let observerAnnotation = MKPointAnnotation()
            observerAnnotation.coordinate = observerCoordinate
            observerAnnotation.title = "Вы"
            mapView.addAnnotation(observerAnnotation)
        }

        var visibleRect = full.boundingMapRect
        if let observerCoordinate {
            let point = MKMapPoint(observerCoordinate)
            let pointRect = MKMapRect(x: point.x, y: point.y, width: 1, height: 1)
            visibleRect = visibleRect.union(pointRect)
        }

        mapView.setVisibleMapRect(
            visibleRect,
            edgePadding: UIEdgeInsets(top: 140, left: 40, bottom: 220, right: 40),
            animated: true
        )
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let line = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: line)
                renderer.strokeColor = UIColor.systemCyan.withAlphaComponent(0.75)
                renderer.lineWidth = 2
                renderer.lineDashPattern = [6, 4]
                return renderer
            }

            guard let circle = overlay as? MKCircle else {
                return MKOverlayRenderer(overlay: overlay)
            }

            let renderer = MKCircleRenderer(circle: circle)
            if circle.title == "confident" {
                renderer.strokeColor = UIColor.systemGreen.withAlphaComponent(0.8)
                renderer.fillColor = UIColor.systemGreen.withAlphaComponent(0.20)
            } else {
                renderer.strokeColor = UIColor.systemOrange.withAlphaComponent(0.8)
                renderer.fillColor = UIColor.systemOrange.withAlphaComponent(0.18)
            }
            renderer.lineWidth = 1.5
            return renderer
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            let identifier = "coverageAnnotation"
            let view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView
                ?? MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            view.annotation = annotation
            view.canShowCallout = true
            if annotation.title??.lowercased() == "вы" {
                view.markerTintColor = .systemBlue
            } else {
                view.markerTintColor = .systemOrange
            }
            return view
        }
    }
}
