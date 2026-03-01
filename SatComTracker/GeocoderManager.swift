import Foundation
import CoreLocation
import Combine

// Геокодер и работа с картой

class GeocoderManager: ObservableObject {
    private let geocoder = CLGeocoder()
    
    @Published var searchResults: [LocationSearchResult] = []
    @Published var isSearching = false
    @Published var searchError: String?
    
    /// Текущий текст запроса (используется для дебаунса)
    @Published var query: String = ""
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupQueryPipeline()
    }
    
    private func setupQueryPipeline() {
        $query
            .removeDuplicates()
            .debounce(for: .milliseconds(400), scheduler: DispatchQueue.main)
            .sink { [weak self] text in
                self?.performSearch(with: text)
            }
            .store(in: &cancellables)
    }
    
    func searchAddress(_ query: String) {
        self.query = query
    }
    
    private func performSearch(with text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Очищаем и отменяем поиск, если строка пустая или слишком короткая
        guard !trimmed.isEmpty, trimmed.count >= 3 else {
            geocoder.cancelGeocode()
            searchResults = []
            searchError = nil
            isSearching = false
            return
        }
        
        isSearching = true
        searchError = nil
        
        geocoder.cancelGeocode()
        geocoder.geocodeAddressString(trimmed) { [weak self] placemarks, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                self.isSearching = false
                
                if let error = error {
                    self.searchError = error.localizedDescription
                    self.searchResults = []
                    return
                }
                
                guard let placemarks = placemarks, !placemarks.isEmpty else {
                    self.searchResults = []
                    return
                }
                
                self.searchResults = placemarks.compactMap { placemark in
                    guard let location = placemark.location else { return nil }
                    
                    let title = [
                        placemark.name,
                        placemark.locality,
                        placemark.country
                    ].compactMap { $0 }.joined(separator: ", ")
                    
                    return LocationSearchResult(
                        id: UUID(),
                        title: title,
                        subtitle: String(format: "%.4f°, %.4f°", location.coordinate.latitude, location.coordinate.longitude),
                        coordinate: location.coordinate
                    )
                }
            }
        }
    }
    
    func getAddressFromCoordinates(latitude: Double, longitude: Double, completion: @escaping (String?) -> Void) {
        let location = CLLocation(latitude: latitude, longitude: longitude)
        
        geocoder.reverseGeocodeLocation(location) { placemarks, error in
            if let error = error {
                print("Reverse geocoding error: \(error)")
                completion(nil)
                return
            }
            
            guard let placemark = placemarks?.first else {
                completion(nil)
                return
            }
            
            let address = [
                placemark.name,
                placemark.locality,
                placemark.country
            ].compactMap { $0 }.joined(separator: ", ")
            
            completion(address.isEmpty ? nil : address)
        }
    }
}
