import Foundation
import CoreLocation
import Combine

// Геокодер и работа с картой

class GeocoderManager: ObservableObject {
    private let geocoder = CLGeocoder()
    
    @Published var searchResults: [LocationSearchResult] = []
    @Published var isSearching = false
    @Published var searchError: String?
    
    func searchAddress(_ query: String) {
        guard !query.isEmpty else {
            searchResults = []
            return
        }
        
        isSearching = true
        searchError = nil
        
        geocoder.geocodeAddressString(query) { [weak self] placemarks, error in
            DispatchQueue.main.async {
                self?.isSearching = false
                
                if let error = error {
                    self?.searchError = error.localizedDescription
                    return
                }
                
                guard let placemarks = placemarks, !placemarks.isEmpty else {
                    self?.searchResults = []
                    return
                }
                
                self?.searchResults = placemarks.compactMap { placemark in
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
