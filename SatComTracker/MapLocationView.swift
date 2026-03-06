import SwiftUI
import MapKit

struct MapLocationView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var settings: AppSettings
    @ObservedObject var locationManager: LocationManager
    @StateObject private var geocoderManager = GeocoderManager()
    
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 55.7558, longitude: 37.6173),
        span: MKCoordinateSpan(latitudeDelta: 10, longitudeDelta: 10)
    )
    @State private var selectedCoordinate: CLLocationCoordinate2D?
    @State private var searchText = ""
    @State private var selectedAddress: String?
    @State private var mapType: MKMapType = .standard
    @State private var gpsStatusMessage: String?
    @State private var gpsStatusIsError = false
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        NavigationView {
            ZStack {
                MapView(region: $region, selectedCoordinate: $selectedCoordinate, mapType: mapType)
                    .ignoresSafeArea()

                VStack(spacing: 10) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        TextField("Поиск города или места", text: $searchText)
                            .autocapitalization(.words)

                        if geocoderManager.isSearching {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(UITheme.surfaceBackground(for: colorScheme).opacity(0.98))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(UITheme.cardBorder(for: colorScheme), lineWidth: 1)
                    )

                    if let gpsStatusMessage {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: gpsStatusIsError ? "location.slash.fill" : "location.fill")
                                .foregroundColor(gpsStatusIsError ? .red : .green)
                                .padding(.top, 2)

                            Text(gpsStatusMessage)
                                .font(.caption)
                                .foregroundColor(gpsStatusIsError ? .red : .secondary)
                                .multilineTextAlignment(.leading)
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(gpsStatusIsError ? Color.red.opacity(0.12) : Color.green.opacity(0.12))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(gpsStatusIsError ? Color.red.opacity(0.3) : Color.green.opacity(0.25), lineWidth: 1)
                        )
                    }

                    if !geocoderManager.searchResults.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(geocoderManager.searchResults) { result in
                                    Button(action: {
                                        selectLocation(result.coordinate, title: result.title)
                                    }) {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(result.title)
                                                .font(.caption)
                                                .fontWeight(.medium)
                                                .lineLimit(1)
                                            Text(result.subtitle)
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(UITheme.surfaceBackground(for: colorScheme))
                                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                .stroke(UITheme.cardBorder(for: colorScheme), lineWidth: 1)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    HStack {
                        Menu {
                            Button("Схема") { mapType = .standard }
                            Button("Спутник") { mapType = .satellite }
                            Button("Гибрид") { mapType = .hybrid }
                        } label: {
                            Image(systemName: "map")
                                .foregroundColor(UITheme.accent(for: colorScheme))
                                .padding(11)
                                .background(UITheme.surfaceBackground(for: colorScheme))
                                .clipShape(Circle())
                                .overlay(Circle().stroke(UITheme.cardBorder(for: colorScheme), lineWidth: 1))
                                .shadow(color: UITheme.shadow(for: colorScheme), radius: 8, y: 3)
                        }
                        Spacer()
                    }

                    Spacer()

                    if let coordinate = selectedCoordinate {
                        VStack(spacing: 8) {
                            if let address = selectedAddress {
                                Text(address)
                                    .font(.caption)
                                    .multilineTextAlignment(.center)
                            }

                            Text(String(format: "Ш: %.4f°, Д: %.4f°", coordinate.latitude, coordinate.longitude))
                                .font(.caption2)
                                .foregroundColor(.secondary)

                            HStack(spacing: 16) {
                                Button("Выбрать") {
                                    settings.manualLatitude = String(format: "%.6f", coordinate.latitude)
                                    settings.manualLongitude = String(format: "%.6f", coordinate.longitude)
                                    settings.lastSelectedAddress = selectedAddress ?? String(
                                        format: "Ш: %.4f°, Д: %.4f°",
                                        coordinate.latitude,
                                        coordinate.longitude
                                    )
                                    settings.locationSource = .map
                                    dismiss()
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.regular)

                                Button("Отмена") {
                                    selectedCoordinate = nil
                                    selectedAddress = nil
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.regular)
                            }
                        }
                        .appCard(cornerRadius: 14)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .padding(.bottom, 12)
            }
            .navigationTitle("Выбор на карте")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                    }
                    .buttonStyle(AppToolbarIconButtonStyle())
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        focusOnUserLocation()
                    }) {
                        Image(systemName: "location.fill")
                    }
                    .buttonStyle(AppToolbarIconButtonStyle())
                }
            }
            .onChange(of: searchText) { newValue in
                geocoderManager.query = newValue
            }
            .onChange(of: selectedCoordinate.map { "\($0.latitude),\($0.longitude)" }) { newValue in
                guard let coordinate = selectedCoordinate else { return }
                geocoderManager.getAddressFromCoordinates(
                    latitude: coordinate.latitude,
                    longitude: coordinate.longitude
                ) { address in
                    selectedAddress = address
                }
            }
            .onAppear {
                if let lat = Double(settings.manualLatitude),
                   let lon = Double(settings.manualLongitude) {
                    region.center = CLLocationCoordinate2D(latitude: lat, longitude: lon)
                }
                refreshGPSStatus()
            }
            .onChange(of: locationManager.authorizationStatus) { _ in
                refreshGPSStatus()
            }
            .onChange(of: locationManager.currentLocation) { _ in
                refreshGPSStatus()
            }
            .onChange(of: locationManager.locationError) { _ in
                refreshGPSStatus()
            }
        }
        .navigationViewStyle(.stack)
    }
    
    private func selectLocation(_ coordinate: CLLocationCoordinate2D, title: String) {
        selectedCoordinate = coordinate
        region.center = coordinate
        region.span = MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
        searchText = title
        geocoderManager.searchResults = []
    }

    private func focusOnUserLocation() {
        if let location = locationManager.currentLocation {
            region.center = location.coordinate
            region.span = MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
            gpsStatusMessage = "GPS активен. Позиция пользователя определена."
            gpsStatusIsError = false
            return
        }

        if !locationManager.hasPermission {
            locationManager.requestLocation()
            switch locationManager.authorizationStatus {
            case .denied, .restricted:
                gpsStatusMessage = "Нет доступа к GPS. Разрешите доступ к геопозиции в настройках телефона."
            case .notDetermined:
                gpsStatusMessage = "Запрошен доступ к GPS. Подтвердите разрешение и попробуйте снова."
            default:
                gpsStatusMessage = "GPS недоступен. Проверьте разрешение на геопозицию."
            }
            gpsStatusIsError = true
            return
        }

        locationManager.startUpdating()
        if let error = locationManager.locationError, !error.isEmpty {
            gpsStatusMessage = "GPS не работает: \(error). Проверьте сигнал и попробуйте на открытом месте."
            gpsStatusIsError = true
        } else {
            gpsStatusMessage = "Ожидание сигнала GPS. Если позиция не появится, проверьте интернет и геолокацию."
            gpsStatusIsError = true
        }
    }

    private func refreshGPSStatus() {
        if let location = locationManager.currentLocation {
            gpsStatusMessage = String(
                format: "GPS активен: Ш %.4f°, Д %.4f°",
                location.coordinate.latitude,
                location.coordinate.longitude
            )
            gpsStatusIsError = false
            return
        }

        if let error = locationManager.locationError, !error.isEmpty {
            gpsStatusMessage = "Ошибка GPS: \(error). Проверьте сигнал и разрешения геолокации."
            gpsStatusIsError = true
            return
        }

        switch locationManager.authorizationStatus {
        case .denied, .restricted:
            gpsStatusMessage = "Доступ к GPS отключен. Включите геолокацию для приложения в настройках телефона."
            gpsStatusIsError = true
        case .notDetermined:
            gpsStatusMessage = nil
            gpsStatusIsError = false
        default:
            gpsStatusMessage = nil
            gpsStatusIsError = false
        }
    }
}

struct MapView: UIViewRepresentable {
    @Binding var region: MKCoordinateRegion
    @Binding var selectedCoordinate: CLLocationCoordinate2D?
    var mapType: MKMapType
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.mapType = mapType
        mapView.showsUserLocation = true
        mapView.showsCompass = true
        mapView.showsScale = true
        
        let longPressGesture = UILongPressGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleLongPress(_:))
        )
        mapView.addGestureRecognizer(longPressGesture)
        
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        mapView.mapType = mapType
        mapView.setRegion(region, animated: true)
        
        mapView.removeAnnotations(mapView.annotations)
        
        if let coordinate = selectedCoordinate {
            let annotation = MKPointAnnotation()
            annotation.coordinate = coordinate
            annotation.title = "Выбранная точка"
            mapView.addAnnotation(annotation)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: MapView
        
        init(_ parent: MapView) {
            self.parent = parent
        }
        
        @objc func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
            if gesture.state == .began {
                guard let mapView = gesture.view as? MKMapView else { return }
                let point = gesture.location(in: mapView)
                let coordinate = mapView.convert(point, toCoordinateFrom: mapView)
                
                parent.selectedCoordinate = coordinate
            }
        }
        
        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            parent.region = mapView.region
        }
        
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if annotation is MKUserLocation {
                return nil
            }
            
            let identifier = "Pin"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKPinAnnotationView
            
            if annotationView == nil {
                annotationView = MKPinAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                annotationView?.canShowCallout = true
                annotationView?.pinTintColor = .red
            } else {
                annotationView?.annotation = annotation
            }
            
            return annotationView
        }
    }
}
