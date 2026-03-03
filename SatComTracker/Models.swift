import Foundation
import CoreLocation

// Настройки API
struct APIConfig {
    static let baseURL = "https://api.n2yo.com/rest/v1/satellite"
    static let maxConcurrentRequests = 5
    static let requestTimeout: TimeInterval = 15
    static let retryCount = 3
}

// Модели данных

struct Satellite: Identifiable, Codable {
    let id: Int
    let name: String
    var azimuth: Double
    var elevation: Double
    var distanceKm: Double
    var velocity: Double
    var timestamp: Date
    var isError: Bool
    var errorMessage: String?
    var satelliteLatitude: Double?
    var satelliteLongitude: Double?
    var satelliteAltitudeKm: Double?
    var observerLatitude: Double?
    var observerLongitude: Double?
    
    var isVisible: Bool {
        !isError && elevation >= 0
    }
}

struct CachedData: Codable {
    let satellites: [Satellite]
    let timestamp: Date
    let latitude: Double
    let longitude: Double
    
    init(satellites: [Satellite], timestamp: Date, latitude: Double, longitude: Double) {
        self.satellites = satellites
        self.timestamp = timestamp
        self.latitude = latitude
        self.longitude = longitude
    }
}

struct SatellitePositionsResponse: Codable {
    let info: PositionInfo
    let positions: [PositionData]

    private enum CodingKeys: String, CodingKey {
        case info
        case positions
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        info = try container.decodeIfPresent(PositionInfo.self, forKey: .info) ?? PositionInfo()
        positions = try container.decodeIfPresent([PositionData].self, forKey: .positions) ?? []
    }
    
    struct PositionInfo: Codable {
        let satname: String
        let satid: Int
        let transactionscount: Int

        init(satname: String = "Unknown", satid: Int = 0, transactionscount: Int = 0) {
            self.satname = satname
            self.satid = satid
            self.transactionscount = transactionscount
        }
    }
    
    struct PositionData: Codable {
        let satlatitude: Double
        let satlongitude: Double
        let sataltitude: Double
        let azimuth: Double
        let elevation: Double
        let timestamp: TimeInterval
    }
}

// Результат поиска и модель для карты

struct LocationSearchResult: Identifiable {
    let id: UUID
    let title: String
    let subtitle: String
    let coordinate: CLLocationCoordinate2D
}

struct MapLocation: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
}
