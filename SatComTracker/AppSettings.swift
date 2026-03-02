import SwiftUI
import Combine

// Хранилище Настроек

class AppSettings: ObservableObject {
    @AppStorage("apiKey") var apiKey: String = ""
    @AppStorage("noradIDs") var noradIDsString: String = AppSettings.defaultBuiltInNoradIDsCSV
    @AppStorage("customIDs") var customIDsString: String = ""
    @AppStorage("refreshInterval") var refreshInterval: Int = 3600
    @AppStorage("lastCacheUpdateTime") private var lastCacheUpdateTime: TimeInterval = Date.distantPast.timeIntervalSince1970
    
    @AppStorage("locationSource") var locationSource: LocationSource = .gps
    @AppStorage("manualLatitude") var manualLatitude: String = "55.7558"
    @AppStorage("manualLongitude") var manualLongitude: String = "37.6173"
    @AppStorage("lastSelectedAddress") var lastSelectedAddress: String = ""
    @AppStorage("themeMode") private var themeModeRaw: String = ThemeMode.system.rawValue
    @AppStorage("didInitializeBuiltInSatellites") private var didInitializeBuiltInSatellites: Bool = false
    @AppStorage("updateMode") private var updateModeRaw: String = UpdateMode.automatic.rawValue
    
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

    enum ThemeMode: String, CaseIterable {
        case system = "system"
        case light = "light"
        case dark = "dark"

        var title: String {
            switch self {
            case .system: return "Как в телефоне"
            case .light: return "Светлая"
            case .dark: return "Темная"
            }
        }
    }

    enum UpdateMode: String, CaseIterable {
        case automatic = "automatic"
        case onDemand = "on_demand"
        case disabled = "disabled"

        var title: String {
            switch self {
            case .automatic: return "Автоматически"
            case .onDemand: return "По запросу"
            case .disabled: return "Отключено"
            }
        }

        var description: String {
            switch self {
            case .automatic: return "Обновление по выбранному интервалу"
            case .onDemand: return "Обновление только при нажатии кнопки"
            case .disabled: return "Обновление полностью отключено"
            }
        }
    }
    
    init() {
        if !didInitializeBuiltInSatellites {
            let hasAnySatellites = !noradIDs.isEmpty || !customIDs.isEmpty
            if !hasAnySatellites {
                noradIDs = AppSettings.defaultBuiltInNoradIDs
            }
            didInitializeBuiltInSatellites = true
        }
    }

    private static let defaultBuiltInNoradIDs: [Int] = SatelliteFrequencyLibrary.defaultByNorad.keys.sorted()
    private static let defaultBuiltInNoradIDsCSV: String = SatelliteFrequencyLibrary.defaultByNorad.keys
        .sorted()
        .map(String.init)
        .joined(separator: ",")
    
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
        !allActiveIDs.isEmpty
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

    var themeMode: ThemeMode {
        get { ThemeMode(rawValue: themeModeRaw) ?? .system }
        set {
            themeModeRaw = newValue.rawValue
            objectWillChange.send()
        }
    }

    var preferredColorScheme: ColorScheme? {
        switch themeMode {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    var updateMode: UpdateMode {
        get { UpdateMode(rawValue: updateModeRaw) ?? .automatic }
        set {
            updateModeRaw = newValue.rawValue
            objectWillChange.send()
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
    
    func addCustomIDs(_ ids: [Int]) {
        guard !ids.isEmpty else { return }
        var current = Set(customIDs)
        for id in ids where id > 0 {
            current.insert(id)
        }
        customIDs = Array(current).sorted()
    }
    
    func removeCustomID(_ noradID: Int) {
        customIDs = customIDs.filter { $0 != noradID }
    }

    func removeSatellite(_ noradID: Int) {
        noradIDs = noradIDs.filter { $0 != noradID }
        customIDs = customIDs.filter { $0 != noradID }
    }
    
    func clearAllSatellites() {
        noradIDs = []
        customIDs = []
    }

    func restoreInstalledDefaults() {
        noradIDs = AppSettings.defaultBuiltInNoradIDs
        customIDs = []
        lastCacheUpdate = Date.distantPast
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
