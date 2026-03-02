import SwiftUI
import MapKit

struct SatelliteCoverageMapView: View {
    @Environment(\.dismiss) private var dismiss
    let satellite: Satellite

    @State private var mapType: MKMapType = .hybrid
    @Environment(\.colorScheme) private var colorScheme

    private var coverageData: SatelliteCoverageData? {
        SatelliteCoverageData.make(from: satellite)
    }

    var body: some View {
        NavigationView {
            ZStack {
                if let coverageData {
                    SatelliteCoverageMapRepresentable(
                        coverageData: coverageData,
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
                    HStack {
                        Menu {
                            Button("Схема") { mapType = .standard }
                            Button("Спутник") { mapType = .satellite }
                            Button("Гибрид") { mapType = .hybrid }
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
                    }

                    Spacer()

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
                    }
                    .padding(12)
                    .background(UITheme.surfaceBackground(for: colorScheme).opacity(0.95))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(UITheme.cardBorder(for: colorScheme), lineWidth: 1)
                    )
                }
                .padding(12)
            }
            .navigationTitle("Покрытие: \(satellite.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Закрыть") { dismiss() }
                }
            }
        }
    }

    private var observerCoordinate: CLLocationCoordinate2D? {
        guard let lat = satellite.observerLatitude, let lon = satellite.observerLongitude else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
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
        let longitude = satellite.satelliteLongitude ?? BuiltInGeostationaryLibrary.satellitesByNorad[satellite.id]?.longitudeDeg

        guard let longitude else { return nil }
        let altitudeKm = satellite.satelliteAltitudeKm ?? BuiltInGeostationaryLibrary.geostationaryAltitudeKm

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

        // psi = arccos(k * cos(e)) - e, where k = Re / (Re + h)
        let clamped = max(-1.0, min(1.0, ratio * cos(elevation)))
        let geometricMax = maxGeometricCentralAngleDeg * .pi / 180
        let psi = min(geometricMax, max(0, acos(clamped) - elevation))
        return psi * earthRadiusKm * 1000
    }
}

private struct SatelliteCoverageMapRepresentable: UIViewRepresentable {
    let coverageData: SatelliteCoverageData
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

        mapView.addOverlays([full, confident])

        let satAnnotation = MKPointAnnotation()
        satAnnotation.coordinate = coverageData.subSatelliteCoordinate
        satAnnotation.title = "Спутник"
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
            edgePadding: UIEdgeInsets(top: 80, left: 40, bottom: 160, right: 40),
            animated: true
        )
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
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
