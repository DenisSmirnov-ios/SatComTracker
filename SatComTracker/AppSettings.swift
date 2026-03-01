import SwiftUI
import Combine

// MARK: - 🛠 Хранилище Настроек

class AppSettings: ObservableObject {
    @AppStorage("apiKey") var apiKey: String = ""
    @AppStorage("noradIDs") var noradIDsString: String = ""
    @AppStorage("customIDs") var customIDsString: String = ""
    @AppStorage("refreshInterval") var refreshInterval: Int = 3600
    @AppStorage("lastCacheUpdateTime") private var lastCacheUpdateTime: TimeInterval = Date.distantPast.timeIntervalSince1970
    
    @AppStorage("locationSource") var locationSource: LocationSource = .gps
    @AppStorage("manualLatitude") var manualLatitude: String = "55.7558"
    @AppStorage("manualLongitude") var manualLongitude: String = "37.6173"
    @AppStorage("lastSelectedAddress") var lastSelectedAddress: String = ""
    
    enum LocationSource: String, CaseIterable {
        case gps = "GPS"
        case manual = "Ручной ввод"
        case map = "Карта"
        
        var icon: String {
            switch self {
            case .gps: return "location.circle.fill"
            case .manual: return "pencil.circle.fill"
            case .map: return "map.circle.fill"
            }
        }
        
        var description: String {
            switch self {
            case .gps: return "Автоматическое определение"
            case .manual: return "Ручной ввод координат"
            case .map: return "Выбор на карте"
            }
        }
    }
    
    init() {
        if noradIDsString.isEmpty {
            let defaultIDs = SatcomReference.allSatellites.map { String($0.noradID) }.joined(separator: ",")
            noradIDsString = defaultIDs
        }
    }
    
    var noradIDs: [Int] {
        get {
            noradIDsString.components(separatedBy: ",")
                .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
        }
        set {
            noradIDsString = newValue.map { String($0) }.joined(separator: ",")
            objectWillChange.send()
        }
    }
    
    var customIDs: [Int] {
        get {
            customIDsString.components(separatedBy: ",")
                .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
        }
        set {
            customIDsString = newValue.map { String($0) }.joined(separator: ",")
            objectWillChange.send()
        }
    }
    
    var allActiveIDs: [Int] {
        var all = noradIDs
        all.append(contentsOf: customIDs)
        return Array(Set(all))
    }
    
    var isConfigured: Bool {
        !apiKey.isEmpty && !allActiveIDs.isEmpty
    }
    
    var refreshIntervalText: String {
        switch refreshInterval {
        case 300: return "5 мин"
        case 900: return "15 мин"
        case 1800: return "30 мин"
        case 3600: return "1 ч"
        case 7200: return "2 ч"
        case 14400: return "4 ч"
        default: return "\(refreshInterval / 3600) ч"
        }
    }
    
    func getCurrentCoordinates() -> (latitude: Double, longitude: Double, altitude: Double)? {
        switch locationSource {
        case .manual, .map:
            if let lat = Double(manualLatitude), let lon = Double(manualLongitude) {
                return (lat, lon, 0)
            }
            return nil
        case .gps:
            return nil
        }
    }
    
    func isSatelliteSelected(_ noradID: Int) -> Bool {
        allActiveIDs.contains(noradID)
    }
    
    func toggleSatellite(_ noradID: Int) {
        var ids = noradIDs
        if let index = ids.firstIndex(of: noradID) {
            ids.remove(at: index)
        } else {
            ids.append(noradID)
        }
        noradIDs = ids
    }
    
    func addCustomID(_ noradID: Int) {
        var ids = customIDs
        if !ids.contains(noradID) {
            ids.append(noradID)
            customIDs = ids
        }
    }
    
    func removeCustomID(_ noradID: Int) {
        customIDs = customIDs.filter { $0 != noradID }
    }
    
    func selectAllSatellites() {
        noradIDs = SatcomReference.allSatellites.map { $0.noradID }
    }
    
    func clearAllSatellites() {
        noradIDs = []
        customIDs = []
    }
    
    var lastCacheUpdate: Date {
        get { Date(timeIntervalSince1970: lastCacheUpdateTime) }
        set { lastCacheUpdateTime = newValue.timeIntervalSince1970 }
    }
    
    func shouldRefreshCache() -> Bool {
        Date().timeIntervalSince(lastCacheUpdate) >= Double(refreshInterval)
    }
    
    func updateCacheTime() {
        lastCacheUpdate = Date()
    }
}
