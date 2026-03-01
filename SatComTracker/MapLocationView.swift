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
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    TextField("Поиск города или места", text: $searchText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.words)
                    
                    if geocoderManager.isSearching {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }
                .padding()
                
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
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(8)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.bottom, 8)
                }
                
                ZStack {
                    MapView(region: $region, selectedCoordinate: $selectedCoordinate, mapType: mapType)
                        .edgesIgnoringSafeArea(.bottom)
                    
                    VStack {
                        HStack {
                            Spacer()
                            
                            Menu {
                                Button("Схема") { mapType = .standard }
                                Button("Спутник") { mapType = .satellite }
                                Button("Гибрид") { mapType = .hybrid }
                            } label: {
                                Image(systemName: "map")
                                    .padding(10)
                                    .background(Color.white)
                                    .clipShape(Circle())
                                    .shadow(radius: 3)
                            }
                            .padding()
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
                                        settings.locationSource = .map
                                        dismiss()
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .controlSize(.small)
                                    
                                    Button("Отмена") {
                                        selectedCoordinate = nil
                                        selectedAddress = nil
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                }
                            }
                            .padding()
                            .background(Color(.systemBackground).opacity(0.95))
                            .cornerRadius(12)
                            .shadow(radius: 5)
                            .padding()
                        }
                    }
                }
            }
            .navigationTitle("Выбор на карте")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Отмена") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Моё местоположение") {
                        if let location = locationManager.currentLocation {
                            region.center = location.coordinate
                            region.span = MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
                        }
                    }
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
            }
        }
    }
    
    private func selectLocation(_ coordinate: CLLocationCoordinate2D, title: String) {
        selectedCoordinate = coordinate
        region.center = coordinate
        region.span = MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
        searchText = title
        geocoderManager.searchResults = []
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
                let mapView = gesture.view as! MKMapView
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
