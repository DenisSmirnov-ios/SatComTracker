import Foundation
import Combine

// API Сервис

class SatelliteAPI: ObservableObject {
    @Published var satellites: [Satellite] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var lastUpdateTime: Date?
    
    private let cacheKey = "satelliteCache"
    private let session: URLSession
    private let decoder = JSONDecoder()
    
    init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = APIConfig.requestTimeout
        configuration.httpMaximumConnectionsPerHost = APIConfig.maxConcurrentRequests
        self.session = URLSession(configuration: configuration)
    }
    
    @MainActor
    func fetchSatellites(apiKey: String, noradIDs: [Int], latitude: Double, longitude: Double,
                        altitude: Double = 0, refreshInterval: Int, forceRefresh: Bool = false,
                        onCacheUpdated: (() -> Void)? = nil) async {
        
        if !forceRefresh, let cached = getValidCache(latitude: latitude, longitude: longitude, maxAge: refreshInterval) {
            self.satellites = cached.satellites
            self.lastUpdateTime = cached.timestamp
            return
        }
        
        self.isLoading = true
        self.errorMessage = nil
        
        let batchSize = APIConfig.maxConcurrentRequests
        var allResults: [Int: Satellite] = [:]
        
        for start in stride(from: 0, to: noradIDs.count, by: batchSize) {
            let chunk = Array(noradIDs[start..<min(start + batchSize, noradIDs.count)])
            let chunkResults = await withTaskGroup(of: Satellite?.self) { group in
                for noradID in chunk {
                    group.addTask {
                        await self.fetchSingleSatellite(noradID: noradID, apiKey: apiKey,
                                                       latitude: latitude, longitude: longitude, altitude: altitude)
                    }
                }
                var results: [Int: Satellite] = [:]
                for await result in group {
                    if let satellite = result {
                        results[satellite.id] = satellite
                    }
                }
                return results
            }
            for (id, satellite) in chunkResults {
                allResults[id] = satellite
            }
        }
        
        // В модуле включен SWIFT_DEFAULT_ACTOR_ISOLATION=MainActor, поэтому свойства Satellite
        // считаются MainActor-изолированными. Чтобы не сортировать на главном потоке и при этом
        // не трогать MainActor-свойства в detached-задаче, заранее вычисляем ключи сортировки.
        let sortable = allResults.values.map { satellite in
            (isVisible: satellite.elevation >= 0, elevation: satellite.elevation, satellite: satellite)
        }
        
        let sortedSatellites = await Task.detached(priority: .userInitiated) { () -> [Satellite] in
            sortable
                .sorted {
                    if $0.isVisible != $1.isVisible { return $0.isVisible }
                    return $0.elevation > $1.elevation
                }
                .map(\.satellite)
        }.value
        
        self.satellites = sortedSatellites
        self.lastUpdateTime = Date()
        onCacheUpdated?()
        self.isLoading = false
        self.saveToCache(sortedSatellites, latitude: latitude, longitude: longitude)
    }
    
    private func fetchSingleSatellite(noradID: Int, apiKey: String,
                                      latitude: Double, longitude: Double, altitude: Double) async -> Satellite? {
        
        let urlString = "\(APIConfig.baseURL)/positions/\(noradID)/\(latitude)/\(longitude)/\(altitude)/1?apiKey=\(apiKey)"
        
        guard let url = URL(string: urlString) else {
            return createErrorSatellite(id: noradID, message: "Invalid URL")
        }
        
        for attempt in 0..<APIConfig.retryCount {
            do {
                let (data, response) = try await session.data(from: url)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    continue
                }
                
                switch httpResponse.statusCode {
                case 200:
                    let result = try decoder.decode(SatellitePositionsResponse.self, from: data)
                    guard let pos = result.positions.first else {
                        return createErrorSatellite(id: noradID, message: "No position data")
                    }
                    
                    return Satellite(
                        id: result.info.satid,
                        name: result.info.satname,
                        azimuth: pos.azimuth,
                        elevation: pos.elevation,
                        distanceKm: calculateDistance(
                            observerLat: latitude, observerLon: longitude, observerAlt: altitude,
                            satLat: pos.satlatitude, satLon: pos.satlongitude, satAlt: pos.sataltitude
                        ),
                        velocity: 27600,
                        timestamp: Date(timeIntervalSince1970: pos.timestamp),
                        isError: false
                    )
                    
                case 429:
                    if attempt < APIConfig.retryCount - 1 {
                        let delay = UInt64(pow(2.0, Double(attempt))) * 1_000_000_000
                        try await Task.sleep(nanoseconds: delay)
                        continue
                    }
                    return createErrorSatellite(id: noradID, message: "Rate limit exceeded")
                    
                default:
                    return createErrorSatellite(id: noradID, message: "HTTP \(httpResponse.statusCode)")
                }
                
            } catch {
                if attempt == APIConfig.retryCount - 1 {
                    return createErrorSatellite(id: noradID, message: error.localizedDescription)
                }
                let delay = UInt64(pow(2.0, Double(attempt))) * 1_000_000_000
                try? await Task.sleep(nanoseconds: delay)
            }
        }
        
        return nil
    }
    
    private func getValidCache(latitude: Double, longitude: Double, maxAge: Int) -> (satellites: [Satellite], timestamp: Date)? {
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let cache = try? decoder.decode(CachedData.self, from: data) else {
            return nil
        }
        
        let age = Date().timeIntervalSince(cache.timestamp)
        let locationDiff = abs(cache.latitude - latitude) + abs(cache.longitude - longitude)
        
        guard age < Double(maxAge) && locationDiff < 0.01 else {
            return nil
        }
        
        return (cache.satellites, cache.timestamp)
    }
    
    private func saveToCache(_ satellites: [Satellite], latitude: Double, longitude: Double) {
        let cache = CachedData(satellites: satellites, timestamp: Date(), latitude: latitude, longitude: longitude)
        if let encoded = try? JSONEncoder().encode(cache) {
            UserDefaults.standard.set(encoded, forKey: cacheKey)
        }
    }
    
    private func createErrorSatellite(id: Int, message: String) -> Satellite {
        Satellite(id: id, name: "ID: \(id)", azimuth: 0, elevation: 0,
                 distanceKm: 0, velocity: 0, timestamp: Date(), isError: true, errorMessage: message)
    }
    
    private func calculateDistance(observerLat: Double, observerLon: Double, observerAlt: Double,
                                   satLat: Double, satLon: Double, satAlt: Double) -> Double {
        let earthRadius = 6371.0
        let lat1 = observerLat * .pi / 180
        let lat2 = satLat * .pi / 180
        let dLat = (satLat - observerLat) * .pi / 180
        let dLon = (satLon - observerLon) * .pi / 180
        let a = sin(dLat/2) * sin(dLat/2) + cos(lat1) * cos(lat2) * sin(dLon/2) * sin(dLon/2)
        let c = 2 * atan2(sqrt(a), sqrt(1-a))
        let groundDistance = earthRadius * c
        let altDiff = satAlt - observerAlt
        return sqrt(groundDistance * groundDistance + altDiff * altDiff)
    }
}
