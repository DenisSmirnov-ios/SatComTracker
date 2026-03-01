import Foundation
import CoreLocation

// MARK: - 🔑 Настройки API
struct APIConfig {
    static let baseURL = "https://api.n2yo.com/rest/v1/satellite"
    static let maxConcurrentRequests = 5
    static let requestTimeout: TimeInterval = 15
    static let retryCount = 3
}

// MARK: - 📦 Модели данных

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
    
    var isVisible: Bool {
        elevation >= 0
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
    
    struct PositionInfo: Codable {
        let satname: String
        let satid: Int
        let transactionscount: Int
    }
    
    struct PositionData: Codable {
        let satlatitude: Double
        let satlongitude: Double
        let sataltitude: Double
        let azimuth: Double
        let elevation: Double
        let ra: Double
        let dec: Double
        let timestamp: TimeInterval
        let eclipsed: Bool
    }
}

// MARK: - 📡 Модель частот из файла

struct SatelliteFrequencyData: Identifiable, Codable {
    var id = UUID()
    let number: Int
    var rxFrequency: Double
    var txFrequency: Double
    let spacing: Double
    let bandwidth: Int
    let satelliteName: String
    var isEdited: Bool = false
    var originalRX: Double?
    var originalTX: Double?
}

// MARK: - 🛰️ Справочник SATCOM спутников

struct SatcomReference {
    static let allSatellites: [SatcomSatellite] = [
        SatcomSatellite(noradID: 25967, name: "UFO 10", category: "UFO Серия", defaultChannels: 47),
        SatcomSatellite(noradID: 28117, name: "UFO 11", category: "UFO Серия", defaultChannels: 89),
        SatcomSatellite(noradID: 22787, name: "UFO 2", category: "UFO Серия", defaultChannels: 6),
        SatcomSatellite(noradID: 20253, name: "FLTSATCOM 8", category: "FLTSATCOM", defaultChannels: 13),
        SatcomSatellite(noradID: 29631, name: "Skynet 4C", category: "Skynet", defaultChannels: 9),
        SatcomSatellite(noradID: 30794, name: "Skynet 4E", category: "Skynet", defaultChannels: 2),
        SatcomSatellite(noradID: 32283, name: "Skynet 5A", category: "Skynet", defaultChannels: 3),
        SatcomSatellite(noradID: 33272, name: "Skynet 5B", category: "Skynet", defaultChannels: 11),
        SatcomSatellite(noradID: 36581, name: "Skynet 5C", category: "Skynet", defaultChannels: 8),
        SatcomSatellite(noradID: 36582, name: "Skynet 5D", category: "Skynet", defaultChannels: 8),
        SatcomSatellite(noradID: 35943, name: "COMSATBW 1", category: "COMSAT", defaultChannels: 2),
        SatcomSatellite(noradID: 38098, name: "INTELSAT 22", category: "INTELSAT", defaultChannels: 27),
        SatcomSatellite(noradID: 26694, name: "SICRAL 1", category: "SICRAL", defaultChannels: 1),
        SatcomSatellite(noradID: 34810, name: "SICRAL 1B", category: "SICRAL", defaultChannels: 14),
        SatcomSatellite(noradID: 40614, name: "SICRAL 2", category: "SICRAL", defaultChannels: 10)
    ]
}

struct SatcomSatellite: Identifiable {
    let id = UUID()
    let noradID: Int
    let name: String
    let category: String
    let defaultChannels: Int
}

// MARK: - 🗺️ Результат поиска и модель для карты

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
