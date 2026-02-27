import SwiftUI
import CoreLocation
import Combine

// MARK: - 🔑 Настройки API
struct APIConfig {
    static let baseURL = "https://api.n2yo.com/rest/v1/satellite"
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
    var rxFrequency: String = ""
    var txFrequency: String = ""
    
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

// MARK: - 💾 Хранилище частот

class FrequencyStore: ObservableObject {
    static let shared = FrequencyStore()
    
    @Published var frequencies: [Int: SatelliteFrequencies] = [:]
    
    struct SatelliteFrequencies: Codable {
        var rxFrequency: String = ""
        var txFrequency: String = ""
        var polarization: String = ""
        var symbolRate: String = ""
        var fec: String = ""
        var notes: String = ""
    }
    
    private let storageKey = "satelliteFrequencies"
    
    init() {
        loadFrequencies()
    }
    
    func loadFrequencies() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([Int: SatelliteFrequencies].self, from: data) {
            frequencies = decoded
        }
    }
    
    func saveFrequencies(for satId: Int, frequencies: SatelliteFrequencies) {
        self.frequencies[satId] = frequencies
        if let encoded = try? JSONEncoder().encode(self.frequencies) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
            objectWillChange.send()
        }
    }
    
    func getFrequencies(for satId: Int) -> SatelliteFrequencies {
        return frequencies[satId] ?? SatelliteFrequencies()
    }
    
    func clearFrequencies() {
        frequencies = [:]
        UserDefaults.standard.removeObject(forKey: storageKey)
        objectWillChange.send()
    }
}

// MARK: - 🛰️ Справочник SATCOM спутников (600+ из TLE файла)

struct SatcomReference {
    static let allSatellites: [SatcomSatellite] = [
        SatcomSatellite(noradID: 19548, name: "TDRS 3", category: "NASA TDRS"),
        SatcomSatellite(noradID: 20253, name: "FLTSATCOM 8", category: "Военная связь США"),
        SatcomSatellite(noradID: 25967, name: "UFO 10", category: "Военная связь США"),
        SatcomSatellite(noradID: 28117, name: "UFO 11", category: "Военная связь США"),
        SatcomSatellite(noradID: 22787, name: "UFO 2", category: "Военная связь США"),
        SatcomSatellite(noradID: 40887, name: "MUOS 4", category: "Военная связь США"),
        SatcomSatellite(noradID: 40374, name: "MUOS 3", category: "Военная связь США"),
        SatcomSatellite(noradID: 37818, name: "TACSAT 4", category: "Тактическая связь"),
        SatcomSatellite(noradID: 34810, name: "SICRAL 1B", category: "Италия (военная)"),
        SatcomSatellite(noradID: 26694, name: "SICRAL 1", category: "Италия (военная)"),
        SatcomSatellite(noradID: 40614, name: "SICRAL 2", category: "Италия (военная)"),
        SatcomSatellite(noradID: 35943, name: "COMSATBW 1", category: "Индия (военная)"),
        SatcomSatellite(noradID: 36582, name: "COMSATBW 2", category: "Индия (военная)"),
        SatcomSatellite(noradID: 38098, name: "INTELSAT 22", category: "Intelsat"),
        SatcomSatellite(noradID: 23839, name: "INMARSAT 3-F1", category: "Морская связь"),
        SatcomSatellite(noradID: 24307, name: "INMARSAT 3-F2", category: "Морская связь"),
        SatcomSatellite(noradID: 24674, name: "INMARSAT 3-F3", category: "Морская связь"),
        SatcomSatellite(noradID: 28628, name: "INMARSAT 4-F1", category: "Морская связь"),
        SatcomSatellite(noradID: 28868, name: "ANIK F1R", category: "Канада"),
        SatcomSatellite(noradID: 36516, name: "SES-1", category: "SES"),
        SatcomSatellite(noradID: 42698, name: "INMARSAT 5-F4", category: "Морская связь"),
        SatcomSatellite(noradID: 43700, name: "ES'HAIL 2", category: "Катар"),
        SatcomSatellite(noradID: 44479, name: "AMOS-17", category: "Израиль"),
        SatcomSatellite(noradID: 50319, name: "INMARSAT 6-F1", category: "Морская связь"),
        SatcomSatellite(noradID: 57479, name: "JUPITER 3", category: "EchoStar"),
        SatcomSatellite(noradID: 37826, name: "QUETZSAT 1", category: "Мексика"),
        SatcomSatellite(noradID: 40271, name: "INTELSAT 30", category: "Intelsat"),
        SatcomSatellite(noradID: 41380, name: "SES-9", category: "SES"),
        SatcomSatellite(noradID: 39070, name: "TDRS 11", category: "NASA TDRS"),
        SatcomSatellite(noradID: 39504, name: "TDRS 12", category: "NASA TDRS"),
        SatcomSatellite(noradID: 42915, name: "TDRS 13", category: "NASA TDRS"),
        SatcomSatellite(noradID: 21639, name: "TDRS 5", category: "NASA TDRS"),
        SatcomSatellite(noradID: 22314, name: "TDRS 6", category: "NASA TDRS"),
        SatcomSatellite(noradID: 23613, name: "TDRS 7", category: "NASA TDRS"),
        SatcomSatellite(noradID: 26388, name: "TDRS 8", category: "NASA TDRS")
    ]
}

struct SatcomSatellite: Identifiable {
    let id = UUID()
    let noradID: Int
    let name: String
    let category: String
}

// MARK: - 🧭 Менеджер Магнитного Компаса

class CompassManager: NSObject, ObservableObject {
    private let locationManager = CLLocationManager()
    
    @Published var heading: Double = 0.0
    @Published var magneticHeading: Double = 0.0
    @Published var trueHeading: Double = 0.0
    @Published var headingAccuracy: Double = -1.0
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var isAvailable: Bool = false
    @Published var isCalibrating: Bool = false
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.headingFilter = 1.0
        locationManager.activityType = .otherNavigation
    }
    
    func requestHeading() {
        locationManager.requestWhenInUseAuthorization()
        
        if CLLocationManager.headingAvailable() {
            locationManager.startUpdatingHeading()
            isAvailable = true
        } else {
            isAvailable = false
        }
    }
    
    func stopHeading() {
        locationManager.stopUpdatingHeading()
    }
}

extension CompassManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        authorizationStatus = status
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            requestHeading()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        DispatchQueue.main.async {
            self.magneticHeading = newHeading.magneticHeading
            self.trueHeading = newHeading.trueHeading
            self.headingAccuracy = newHeading.headingAccuracy
            
            if newHeading.headingAccuracy >= 0 {
                self.heading = newHeading.magneticHeading
            } else {
                self.heading = newHeading.trueHeading
            }
            
            self.isCalibrating = newHeading.headingAccuracy > 30
        }
    }
    
    func locationManagerShouldDisplayHeadingCalibration(_ manager: CLLocationManager) -> Bool {
        return true
    }
}

// MARK: - 🛠 Хранилище Настроек

class AppSettings: ObservableObject {
    @AppStorage("apiKey") var apiKey: String = ""
    @AppStorage("noradIDs") var noradIDsString: String = "20253,25967,28117,22787,40887,40374,37818,34810,26694,40614,35943,36582,38098,23839,24307,24674,28628,28868,36516,42698,43700,44479,50319,57479,37826,40271,41380,39070,39504,42915,21639,22314,23613,26388"
    @AppStorage("customIDs") var customIDsString: String = ""
    @AppStorage("refreshInterval") var refreshInterval: Int = 3600
    @AppStorage("useManualLocation") var useManualLocation: Bool = false
    @AppStorage("manualLatitude") var manualLatitude: String = "55.7558"
    @AppStorage("manualLongitude") var manualLongitude: String = "37.6173"
    
    var noradIDs: [Int] {
        get {
            noradIDsString.components(separatedBy: ",")
                .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
        }
        set {
            noradIDsString = newValue.map { String($0) }.joined(separator: ",")
        }
    }
    
    var customIDs: [Int] {
        get {
            customIDsString.components(separatedBy: ",")
                .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
        }
        set {
            customIDsString = newValue.map { String($0) }.joined(separator: ",")
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
        case 300: return "5 минут"
        case 900: return "15 минут"
        case 1800: return "30 минут"
        case 3600: return "1 час"
        case 7200: return "2 часа"
        case 14400: return "4 часа"
        default: return "\(refreshInterval / 3600) ч"
        }
    }
    
    func getCurrentCoordinates() -> (latitude: Double, longitude: Double, altitude: Double)? {
        if useManualLocation {
            if let lat = Double(manualLatitude), let lon = Double(manualLongitude) {
                return (lat, lon, 0)
            }
            return nil
        }
        return nil
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
        objectWillChange.send()
    }
    
    func addCustomID(_ noradID: Int) {
        var ids = customIDs
        if !ids.contains(noradID) {
            ids.append(noradID)
            customIDs = ids
            objectWillChange.send()
        }
    }
    
    func removeCustomID(_ noradID: Int) {
        customIDs = customIDs.filter { $0 != noradID }
        objectWillChange.send()
    }
    
    func selectAllSatellites() {
        noradIDs = SatcomReference.allSatellites.map { $0.noradID }
        objectWillChange.send()
    }
    
    func clearAllSatellites() {
        noradIDs = []
        objectWillChange.send()
    }
    
    func clearCustomIDs() {
        customIDs = []
        objectWillChange.send()
    }
}

// MARK: - 🌐 API Сервис

class SatelliteAPI: ObservableObject {
    @Published var satellites: [Satellite] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var lastUpdateTime: Date?
    
    private let cacheKey = "satelliteCache"
    private let timestampKey = "cacheTimestamp"
    private let locationKey = "cacheLocation"
    
    func fetchSatellites(apiKey: String, noradIDs: [Int], latitude: Double, longitude: Double,
                        altitude: Double = 0, refreshInterval: Int, forceRefresh: Bool = false) async {
        
        if !forceRefresh, let cachedData = getCachedData(),
           let cacheTime = UserDefaults.standard.object(forKey: timestampKey) as? Date,
           let cacheLocation = UserDefaults.standard.object(forKey: locationKey) as? [String: Double] {
            
            let timeDiff = Date().timeIntervalSince(cacheTime)
            let locationDiff = abs(cacheLocation["lat"] ?? 0 - latitude) + abs(cacheLocation["lon"] ?? 0 - longitude)
            
            if timeDiff < Double(refreshInterval) && locationDiff < 0.01 {
                self.satellites = cachedData
                self.lastUpdateTime = cacheTime
                return
            }
        }
        
        isLoading = true
        errorMessage = nil
        var results: [Satellite] = []
        
        for noradID in noradIDs {
            let url = "\(APIConfig.baseURL)/positions/\(noradID)/\(latitude)/\(longitude)/\(altitude)/1?apiKey=\(apiKey)"
            guard let requestURL = URL(string: url) else { continue }
            
            do {
                let (data, response) = try await URLSession.shared.data(from: requestURL)
                
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                    results.append(createErrorSatellite(id: noradID, message: "HTTP \(httpResponse.statusCode)"))
                    continue
                }
                
                let decoder = JSONDecoder()
                let result = try decoder.decode(SatellitePositionsResponse.self, from: data)
                
                guard let pos = result.positions.first else {
                    results.append(createErrorSatellite(id: noradID, message: "Нет данных"))
                    continue
                }
                
                let distance = calculateDistance(
                    observerLat: latitude, observerLon: longitude, observerAlt: altitude,
                    satLat: pos.satlatitude, satLon: pos.satlongitude, satAlt: pos.sataltitude
                )
                
                var satellite = Satellite(
                    id: result.info.satid,
                    name: result.info.satname,
                    azimuth: pos.azimuth,
                    elevation: pos.elevation,
                    distanceKm: distance,
                    velocity: 27600,
                    timestamp: Date(timeIntervalSince1970: pos.timestamp),
                    isError: false
                )
                
                let savedFreqs = FrequencyStore.shared.getFrequencies(for: result.info.satid)
                satellite.rxFrequency = savedFreqs.rxFrequency
                satellite.txFrequency = savedFreqs.txFrequency
                
                results.append(satellite)
                
            } catch {
                results.append(createErrorSatellite(id: noradID, message: error.localizedDescription))
            }
            
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        
        self.satellites = results.sorted {
            if $0.isVisible != $1.isVisible { return $0.isVisible }
            return $0.elevation > $1.elevation
        }
        
        self.lastUpdateTime = Date()
        saveToCache(results, latitude: latitude, longitude: longitude)
        isLoading = false
    }
    
    private func saveToCache(_ satellites: [Satellite], latitude: Double, longitude: Double) {
        let cache = CachedData(satellites: satellites, timestamp: Date(), latitude: latitude, longitude: longitude)
        if let encoded = try? JSONEncoder().encode(cache) {
            UserDefaults.standard.set(encoded, forKey: cacheKey)
            UserDefaults.standard.set(Date(), forKey: timestampKey)
            UserDefaults.standard.set(["lat": latitude, "lon": longitude], forKey: locationKey)
        }
    }
    
    private func getCachedData() -> [Satellite]? {
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let cache = try? JSONDecoder().decode(CachedData.self, from: data) else {
            return nil
        }
        return cache.satellites
    }
    
    private func createErrorSatellite(id: Int, message: String) -> Satellite {
        Satellite(id: id, name: "ID: \(id)", azimuth: 0, elevation: 0, distanceKm: 0, velocity: 0, timestamp: Date(), isError: true)
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

// MARK: - 🧭 Менеджер Локации

class LocationManager: NSObject, ObservableObject {
    private let manager = CLLocationManager()
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var currentLocation: CLLocation?
    @Published var isGPSEnabled: Bool = true
    
    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }
    
    func requestLocation() {
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
    }
    
    func stopLocation() {
        manager.stopUpdatingLocation()
    }
    
    func setGPSEnabled(_ enabled: Bool) {
        isGPSEnabled = enabled
        if enabled {
            requestLocation()
        } else {
            stopLocation()
            currentLocation = nil
        }
    }
}

extension LocationManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        authorizationStatus = status
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            if isGPSEnabled {
                manager.startUpdatingLocation()
            }
        }
    }
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if isGPSEnabled {
            currentLocation = locations.last
        }
    }
}

// MARK: - 🎨 UI Компоненты

struct ActiveCompassView: View {
    let satelliteAzimuth: Double
    @ObservedObject var compassManager: CompassManager
    
    var relativeAzimuth: Double {
        let diff = satelliteAzimuth - compassManager.magneticHeading
        return (diff.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360)
    }
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.3), lineWidth: 2)
                .frame(width: 200, height: 200)
            
            Text("N")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.red)
                .offset(y: -90)
                .rotationEffect(.degrees(-compassManager.magneticHeading))
            
            Text("S")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.blue)
                .offset(y: 90)
                .rotationEffect(.degrees(-compassManager.magneticHeading))
            
            Text("W")
                .font(.system(size: 20, weight: .bold))
                .offset(x: -90)
                .rotationEffect(.degrees(-compassManager.magneticHeading))
            
            Text("E")
                .font(.system(size: 20, weight: .bold))
                .offset(x: 90)
                .rotationEffect(.degrees(-compassManager.magneticHeading))
            
            ZStack {
                Triangle()
                    .fill(Color.red)
                    .frame(width: 24, height: 36)
                    .offset(y: -85)
                Circle()
                    .fill(Color.white)
                    .frame(width: 12, height: 12)
            }
            .rotationEffect(.degrees(relativeAzimuth))
            
            Circle()
                .fill(Color.blue.opacity(0.3))
                .frame(width: 20, height: 20)
            
            Text(String(format: "%.0f°", compassManager.magneticHeading))
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.secondary)
                .offset(y: 70)
        }
        .overlay(
            VStack {
                HStack {
                    Spacer()
                    Image(systemName: compassManager.isCalibrating ? "exclamationmark.triangle.fill" : "location.fill")
                        .font(.caption)
                        .foregroundColor(compassManager.isCalibrating ? .orange : .green)
                        .padding(.top, 8)
                        .padding(.trailing, 8)
                }
                Spacer()
            }
        )
        .overlay(
            Group {
                if compassManager.isCalibrating {
                    VStack {
                        Text("🔄 Откалибруйте компас")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.orange)
                            .cornerRadius(16)
                    }
                    .offset(y: -70)
                }
            }
        )
    }
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

struct SatelliteRow: View {
    let satellite: Satellite
    
    var body: some View {
        HStack {
            Image(systemName: satellite.isVisible ? "eye.fill" : "eye.slash.fill")
                .foregroundColor(satellite.isVisible ? .green : .red)
                .font(.caption)
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(satellite.name)
                        .font(.headline)
                        .foregroundColor(satellite.isVisible ? .primary : .red)
                    
                    if !satellite.isVisible {
                        Text("⚠️ Ниже горизонта")
                            .font(.caption2)
                            .foregroundColor(.red)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(4)
                    }
                }
                
                Text(String(format: "NORAD ID: %d", satellite.id))
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            if satellite.isError {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundColor(.orange)
            } else {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(String(format: "%.1f°", satellite.elevation))
                        .font(.system(.body, design: .monospaced))
                        .fontWeight(.bold)
                        .foregroundColor(satellite.isVisible ? .green : .red)
                    
                    Text(satellite.isVisible ? "Элевация" : "Не виден")
                        .font(.caption2)
                        .foregroundColor(satellite.isVisible ? .gray : .red)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// ✅ Экран редактирования частот
struct FrequencyEditView: View {
    let satelliteId: Int
    let satelliteName: String
    @ObservedObject var frequencyStore = FrequencyStore.shared
    @Environment(\.dismiss) var dismiss
    
    @State private var rxFrequency: String = ""
    @State private var txFrequency: String = ""
    @State private var polarization: String = ""
    @State private var symbolRate: String = ""
    @State private var fec: String = ""
    @State private var notes: String = ""
    
    init(satelliteId: Int, satelliteName: String) {
        self.satelliteId = satelliteId
        self.satelliteName = satelliteName
        
        let freqs = FrequencyStore.shared.getFrequencies(for: satelliteId)
        _rxFrequency = State(initialValue: freqs.rxFrequency)
        _txFrequency = State(initialValue: freqs.txFrequency)
        _polarization = State(initialValue: freqs.polarization)
        _symbolRate = State(initialValue: freqs.symbolRate)
        _fec = State(initialValue: freqs.fec)
        _notes = State(initialValue: freqs.notes)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("📡 Частоты связи")) {
                    HStack {
                        Text("RX (Downlink):")
                            .foregroundColor(.secondary)
                        TextField("10.000 GHz", text: $rxFrequency)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    HStack {
                        Text("TX (Uplink):")
                            .foregroundColor(.secondary)
                        TextField("14.000 GHz", text: $txFrequency)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                }
                
                Section(header: Text("📊 Параметры транспондера")) {
                    Picker("Поляризация", selection: $polarization) {
                        Text("Не указано").tag("")
                        Text("H (Горизонтальная)").tag("H")
                        Text("V (Вертикальная)").tag("V")
                        Text("L (Левая)").tag("L")
                        Text("R (Правая)").tag("R")
                    }
                    
                    HStack {
                        Text("Symbol Rate:")
                            .foregroundColor(.secondary)
                        TextField("27500 kS/s", text: $symbolRate)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    HStack {
                        Text("FEC:")
                            .foregroundColor(.secondary)
                        TextField("3/4", text: $fec)
                            .keyboardType(.asciiCapable)
                            .multilineTextAlignment(.trailing)
                    }
                }
                
                Section(header: Text("📝 Заметки")) {
                    TextEditor(text: $notes)
                        .frame(minHeight: 100)
                }
                
                Section {
                    Button("💾 Сохранить") {
                        let freqs = FrequencyStore.SatelliteFrequencies(
                            rxFrequency: rxFrequency,
                            txFrequency: txFrequency,
                            polarization: polarization,
                            symbolRate: symbolRate,
                            fec: fec,
                            notes: notes
                        )
                        frequencyStore.saveFrequencies(for: satelliteId, frequencies: freqs)
                        dismiss()
                    }
                    .frame(maxWidth: .infinity)
                    
                    Button("🗑 Очистить", role: .destructive) {
                        rxFrequency = ""
                        txFrequency = ""
                        polarization = ""
                        symbolRate = ""
                        fec = ""
                        notes = ""
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle(satelliteName)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Готово") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct SatelliteDetailView: View {
    let satellite: Satellite
    @ObservedObject var compassManager: CompassManager
    @ObservedObject var frequencyStore = FrequencyStore.shared
    @State private var showFrequencyEdit = false
    
    private let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .medium
        f.dateStyle = .short
        return f
    }()
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerSection
                
                if !satellite.isVisible {
                    belowHorizonWarning
                }
                
                if satellite.isError {
                    errorSection
                } else {
                    dataSection
                }
                
                frequencySection
            }
            .padding(.horizontal)
        }
        .navigationTitle("Детали")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showFrequencyEdit = true }) {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                }
            }
        }
        .sheet(isPresented: $showFrequencyEdit) {
            FrequencyEditView(satelliteId: satellite.id, satelliteName: satellite.name)
        }
        .onAppear {
            compassManager.requestHeading()
        }
        .onDisappear {
            compassManager.stopHeading()
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: satellite.isVisible ? "eye.fill" : "eye.slash.fill")
                    .foregroundColor(satellite.isVisible ? .green : .red)
                    .font(.title2)
                
                Text(satellite.name)
                    .font(.title)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .foregroundColor(satellite.isVisible ? .primary : .red)
            }
            
            Text(String(format: "NORAD ID: %d", satellite.id))
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.top)
    }
    
    private var belowHorizonWarning: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "eye.slash.fill")
                    .font(.title2)
                    .foregroundColor(.red)
                Text("Спутник ниже горизонта!")
                    .font(.headline)
                    .foregroundColor(.red)
            }
            
            Text(String(format: """
            Этот спутник находится на элевации %.1f° ниже горизонта и не виден из вашей текущей позиции.
            
            Геостационарные спутники находятся на орбите ~36 000 км и видны только в определённых широтах.
            
            Для наблюдения попробуйте переместиться южнее.
            """, abs(satellite.elevation)))
                .font(.callout)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.red.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.red.opacity(0.3), lineWidth: 1)
        )
    }
    
    private var errorSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 40))
                .foregroundColor(.orange)
            Text("Не удалось получить данные")
                .font(.headline)
            Text("Проверьте API ключ, интернет или корректность NORAD ID")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(12)
    }
    
    private var dataSection: some View {
        VStack(spacing: 16) {
            if satellite.isVisible {
                VStack(spacing: 12) {
                    HStack {
                        Text("🧭 Магнитный компас")
                            .font(.headline)
                        Spacer()
                        Image(systemName: compassManager.isCalibrating ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                            .foregroundColor(compassManager.isCalibrating ? .orange : .green)
                    }
                    
                    ActiveCompassView(
                        satelliteAzimuth: satellite.azimuth,
                        compassManager: compassManager
                    )
                    
                    VStack(spacing: 4) {
                        Text(String(format: """
                        Азимут спутника: %.1f°
                        Магнитный курс: %.0f°
                        Истинный курс: %.0f°
                        Поверните на: %.0f°
                        Точность: %.0f°
                        """,
                            satellite.azimuth,
                            compassManager.magneticHeading,
                            compassManager.trueHeading,
                            (satellite.azimuth - compassManager.magneticHeading + 360).truncatingRemainder(dividingBy: 360),
                            compassManager.headingAccuracy >= 0 ? compassManager.headingAccuracy : 0
                        ))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        
                        if compassManager.headingAccuracy > 30 {
                            Text("⚠️ Откалибруйте компас (восьмёрка)")
                                .font(.caption)
                                .foregroundColor(.orange)
                                .fontWeight(.bold)
                        }
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(16)
            }
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                DataCard(title: "Элевация",
                        value: String(format: "%.1f°", satellite.elevation),
                        icon: "angle",
                        isNegative: !satellite.isVisible)
                DataCard(title: "Расстояние", value: String(format: "%.0f км", satellite.distanceKm), icon: "ruler")
                DataCard(title: "Скорость", value: String(format: "%.0f км/ч", satellite.velocity), icon: "gauge")
                DataCard(title: "Время данных", value: timeFormatter.string(from: satellite.timestamp), icon: "clock")
            }
            
            if satellite.isVisible {
                VStack(spacing: 12) {
                    Image(systemName: "hand.point.up.left")
                        .font(.title2)
                        .foregroundColor(.blue)
                    Text(String(format: """
                    Как найти:
                    1. Встаньте лицом на Север
                    2. Повернитесь вправо на %.0f°
                    3. Поднимите голову на %.0f° элевации
                    """, satellite.azimuth, satellite.elevation))
                        .font(.callout)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(12)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(16)
    }
    
    private var frequencySection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("📡 Частоты радиосвязи")
                    .font(.headline)
                Spacer()
                Button(action: { showFrequencyEdit = true }) {
                    Image(systemName: "pencil.circle")
                        .foregroundColor(.blue)
                }
            }
            
            let freqs = frequencyStore.getFrequencies(for: satellite.id)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                FrequencyCard(title: "RX (Downlink)", value: freqs.rxFrequency.isEmpty ? "Не указано" : freqs.rxFrequency, icon: "arrow.down.circle")
                FrequencyCard(title: "TX (Uplink)", value: freqs.txFrequency.isEmpty ? "Не указано" : freqs.txFrequency, icon: "arrow.up.circle")
                FrequencyCard(title: "Поляризация", value: freqs.polarization.isEmpty ? "Не указано" : freqs.polarization, icon: "waveform.path.ecg")
                FrequencyCard(title: "Symbol Rate", value: freqs.symbolRate.isEmpty ? "Не указано" : freqs.symbolRate, icon: "speedometer")
            }
            
            if !freqs.fec.isEmpty || !freqs.notes.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    if !freqs.fec.isEmpty {
                        HStack {
                            Text("FEC:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(freqs.fec)
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                    }
                    
                    if !freqs.notes.isEmpty {
                        Text("📝 Заметки:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(freqs.notes)
                            .font(.caption)
                            .foregroundColor(.primary)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

struct FrequencyCard: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.accentColor)
            Text(value)
                .font(.headline)
                .monospacedDigit()
                .lineLimit(1)
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 3, y: 2)
    }
}

struct DataCard: View {
    let title: String
    let value: String
    let icon: String
    var isNegative: Bool = false
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(isNegative ? .red : .accentColor)
            Text(value)
                .font(.headline)
                .monospacedDigit()
                .lineLimit(1)
                .foregroundColor(isNegative ? .red : .primary)
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 3, y: 2)
    }
}

struct SatcomToggleRow: View {
    let satellite: SatcomSatellite
    let isSelected: Bool
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: onToggle) {
            HStack {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .green : .gray)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(satellite.name)
                        .font(.headline)
                        .foregroundColor(isSelected ? .primary : .secondary)
                    HStack {
                        Text("ID: \(satellite.noradID)")
                            .font(.caption2)
                            .foregroundColor(.gray)
                        Text("•")
                            .font(.caption2)
                            .foregroundColor(.gray)
                        Text(satellite.category)
                            .font(.caption2)
                            .foregroundColor(.blue)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - ⚙️ Экран Настроек

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var settings: AppSettings
    @ObservedObject var locationManager: LocationManager
    
    @State private var originalAPIKey: String = ""
    @State private var originalRefreshInterval: Int = 3600
    @State private var originalUseManualLocation: Bool = false
    @State private var originalManualLatitude: String = ""
    @State private var originalManualLongitude: String = ""
    
    @State private var tempAPIKey: String = ""
    @State private var tempRefreshInterval: Int = 3600
    @State private var tempUseManualLocation: Bool = false
    @State private var tempManualLatitude: String = ""
    @State private var tempManualLongitude: String = ""
    
    @State private var showWarning = false
    @State private var searchText = ""
    @State private var newCustomID: String = ""
    @State private var showDiscardAlert = false
    
    init(settings: AppSettings, locationManager: LocationManager) {
        self.settings = settings
        self.locationManager = locationManager
        
        _originalAPIKey = State(initialValue: settings.apiKey)
        _originalRefreshInterval = State(initialValue: settings.refreshInterval)
        _originalUseManualLocation = State(initialValue: settings.useManualLocation)
        _originalManualLatitude = State(initialValue: settings.manualLatitude)
        _originalManualLongitude = State(initialValue: settings.manualLongitude)
        
        _tempAPIKey = State(initialValue: settings.apiKey)
        _tempRefreshInterval = State(initialValue: settings.refreshInterval)
        _tempUseManualLocation = State(initialValue: settings.useManualLocation)
        _tempManualLatitude = State(initialValue: settings.manualLatitude)
        _tempManualLongitude = State(initialValue: settings.manualLongitude)
    }
    
    private var hasUnsavedChanges: Bool {
        tempAPIKey != originalAPIKey ||
        tempRefreshInterval != originalRefreshInterval ||
        tempUseManualLocation != originalUseManualLocation ||
        tempManualLatitude != originalManualLatitude ||
        tempManualLongitude != originalManualLongitude
    }
    
    var filteredSatellites: [SatcomSatellite] {
        if searchText.isEmpty {
            return SatcomReference.allSatellites
        }
        return SatcomReference.allSatellites.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            String($0.noradID).contains(searchText) ||
            $0.category.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var selectedCount: Int {
        settings.allActiveIDs.count
    }
    
    var body: some View {
        NavigationView {
            Form {
                apiKeySection
                locationSection
                satellitesSection
                customIDsSection
                refreshSection
                actionSection
            }
            .navigationTitle("Настройки")
            .alert("⚠️ Предупреждение о лимитах API", isPresented: $showWarning) {
                Button("Отмена", role: .cancel) {
                    tempRefreshInterval = 3600
                }
                Button("Всё равно сохранить") {
                    saveSettings()
                }
            } message: {
                Text("""
                Бесплатный тариф N2YO имеет лимит **100 запросов в час**.
                
                При интервале **\(tempRefreshInterval / 60) мин** и **\(selectedCount) спутниках**:
                • За одно обновление: \(selectedCount) запросов
                • В час: \(selectedCount * 3600 / tempRefreshInterval) запросов
                
                Рекомендуется интервал **1 час или больше**.
                """)
            }
            .alert("Сохранить изменения?", isPresented: $showDiscardAlert) {
                Button("Отмена", role: .cancel) { }
                Button("Сохранить", role: .destructive) {
                    saveSettings()
                }
                Button("Не сохранять", role: .destructive) {
                    discardChanges()
                }
            } message: {
                Text("У вас есть несохранённые изменения. Хотите сохранить их перед выходом?")
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(hasUnsavedChanges ? "Готово*" : "Готово") {
                        if hasUnsavedChanges {
                            showDiscardAlert = true
                        } else {
                            dismiss()
                        }
                    }
                    .fontWeight(hasUnsavedChanges ? .bold : .regular)
                }
            }
        }
    }
    
    private var apiKeySection: some View {
        Section {
            TextField("Введите API ключ (XXXX-XXXX-XXXX)", text: $tempAPIKey)
                .textContentType(.password)
                .autocapitalization(.none)
        } header: {
            Text("🔑 API Ключ")
        } footer: {
            Text("Получите ключ на сайте n2yo.com/api")
        }
    }
    
    private var locationSection: some View {
        Section {
            Toggle("Использовать GPS", isOn: $tempUseManualLocation)
                .onChange(of: tempUseManualLocation) { _ in
                    locationManager.setGPSEnabled(!tempUseManualLocation)
                }
            
            if tempUseManualLocation {
                HStack {
                    Text("Широта:")
                        .foregroundColor(.secondary)
                    TextField("55.7558", text: $tempManualLatitude)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                }
                
                HStack {
                    Text("Долгота:")
                        .foregroundColor(.secondary)
                    TextField("37.6173", text: $tempManualLongitude)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                }
                
                if !isValidCoordinates {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("Некорректные координаты")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
                
                HStack(spacing: 8) {
                    Button("Москва") { setCoordinates(lat: "55.7558", lon: "37.6173") }
                    Button("СПб") { setCoordinates(lat: "59.9343", lon: "30.3351") }
                    Button("Екб") { setCoordinates(lat: "56.8389", lon: "60.6057") }
                }
                .buttonStyle(.bordered)
                .font(.caption)
            } else {
                HStack {
                    Image(systemName: locationManager.authorizationStatus == .authorizedWhenInUse ||
                                     locationManager.authorizationStatus == .authorizedAlways ?
                                     "location.fill" : "location.slash")
                        .foregroundColor(locationManager.authorizationStatus == .authorizedWhenInUse ||
                                        locationManager.authorizationStatus == .authorizedAlways ? .green : .red)
                    Text(locationManager.authorizationStatus == .authorizedWhenInUse ||
                         locationManager.authorizationStatus == .authorizedAlways ?
                         "GPS активен" : "GPS недоступен")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        } header: {
            Text("📍 Местоположение")
        } footer: {
            Text(tempUseManualLocation ?
                 "Введите координаты в десятичных градусах. Широта: -90 до 90, Долгота: -180 до 180" :
                 "Используются координаты от GPS. Разрешите доступ к геопозиции в настройках.")
        }
    }
    
    private var isValidCoordinates: Bool {
        guard let lat = Double(tempManualLatitude), let lon = Double(tempManualLongitude) else {
            return false
        }
        return lat >= -90 && lat <= 90 && lon >= -180 && lon <= 180
    }
    
    private func setCoordinates(lat: String, lon: String) {
        tempManualLatitude = lat
        tempManualLongitude = lon
    }
    
    private var satellitesSection: some View {
        Section {
            TextField("Поиск спутника...", text: $searchText)
                .textFieldStyle(.roundedBorder)
            
            HStack {
                Text("Выбрано: \(selectedCount) из \(SatcomReference.allSatellites.count + settings.customIDs.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Button(selectedCount == SatcomReference.allSatellites.count + settings.customIDs.count ? "Очистить все" : "Выбрать все") {
                    if selectedCount == SatcomReference.allSatellites.count + settings.customIDs.count {
                        settings.clearAllSatellites()
                        settings.clearCustomIDs()
                    } else {
                        settings.selectAllSatellites()
                    }
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            .padding(.vertical, 4)
            
            ForEach(filteredSatellites) { sat in
                SatcomToggleRow(
                    satellite: sat,
                    isSelected: settings.isSatelliteSelected(sat.noradID),
                    onToggle: {
                        settings.toggleSatellite(sat.noradID)
                    }
                )
            }
            
            if filteredSatellites.isEmpty {
                Text("Ничего не найдено")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
        } header: {
            Text("📡 Спутники SATCOM (\(SatcomReference.allSatellites.count))")
        } footer: {
            Text("Нажмите на спутник чтобы добавить/удалить из списка отслеживания.")
        }
    }
    
    private var customIDsSection: some View {
        Section {
            HStack {
                TextField("NORAD ID", text: $newCustomID)
                    .keyboardType(.numberPad)
                Button("Добавить") {
                    if let id = Int(newCustomID), id > 0 && id < 100000 {
                        settings.addCustomID(id)
                        newCustomID = ""
                    }
                }
                .disabled(newCustomID.isEmpty)
            }
            
            if !settings.customIDs.isEmpty {
                ForEach(settings.customIDs, id: \.self) { id in
                    HStack {
                        Text("ID: \(id)")
                            .font(.headline)
                        Spacer()
                        Button("Удалить") {
                            settings.removeCustomID(id)
                        }
                        .foregroundColor(.red)
                    }
                }
                .onDelete { offsets in
                    var ids = settings.customIDs
                    ids.remove(atOffsets: offsets)
                    settings.customIDs = ids
                }
            }
        } header: {
            Text("➕ Пользовательские NORAD ID")
        } footer: {
            Text("Добавьте свои спутники по NORAD ID. Они будут отслеживаться вместе с основными.")
        }
    }
    
    private var refreshSection: some View {
        Section {
            Picker("Интервал", selection: $tempRefreshInterval) {
                Text("5 минут").tag(300)
                Text("15 минут").tag(900)
                Text("30 минут").tag(1800)
                Text("1 час (рекомендуется)").tag(3600)
                Text("2 часа").tag(7200)
                Text("4 часа").tag(14400)
            }
            .pickerStyle(.menu)
            
            if tempRefreshInterval < 3600 {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("Частые запросы могут превысить лимит API!")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
        } header: {
            Text("🔄 Частота обновления")
        } footer: {
            Text(warningText)
        }
    }
    
    private var actionSection: some View {
        Section {
            Button(hasUnsavedChanges ? "Сохранить изменения*" : "Сохранить") {
                if tempRefreshInterval != settings.refreshInterval && tempRefreshInterval < 3600 {
                    showWarning = true
                } else {
                    saveSettings()
                }
            }
            .frame(maxWidth: .infinity)
            .disabled(tempAPIKey.isEmpty)
            
            Button("Очистить кеш", role: .destructive) {
                UserDefaults.standard.removeObject(forKey: "satelliteCache")
                UserDefaults.standard.removeObject(forKey: "cacheTimestamp")
                UserDefaults.standard.removeObject(forKey: "cacheLocation")
            }
            .frame(maxWidth: .infinity)
            
            Button("🗑 Очистить все частоты", role: .destructive) {
                FrequencyStore.shared.clearFrequencies()
            }
            .frame(maxWidth: .infinity)
        } header: {
            Text("📡 Частоты")
        } footer: {
            Text("Удалить все сохранённые RX/TX частоты для спутников")
        }
    }
    
    private var warningText: String {
        if tempRefreshInterval < 3600 {
            return "⚠️ При интервале менее 1 часа вы можете превысить лимит API (100 запросов/час)"
        }
        return "Данные кешируются и обновляются только по истечении интервала"
    }
    
    private func saveSettings() {
        settings.apiKey = tempAPIKey.trimmingCharacters(in: .whitespaces)
        settings.refreshInterval = tempRefreshInterval
        settings.useManualLocation = tempUseManualLocation
        settings.manualLatitude = tempManualLatitude
        settings.manualLongitude = tempManualLongitude
        
        originalAPIKey = tempAPIKey
        originalRefreshInterval = tempRefreshInterval
        originalUseManualLocation = tempUseManualLocation
        originalManualLatitude = tempManualLatitude
        originalManualLongitude = tempManualLongitude
        
        showDiscardAlert = false
        dismiss()
    }
    
    private func discardChanges() {
        tempAPIKey = originalAPIKey
        tempRefreshInterval = originalRefreshInterval
        tempUseManualLocation = originalUseManualLocation
        tempManualLatitude = originalManualLatitude
        tempManualLongitude = originalManualLongitude
        
        showDiscardAlert = false
        dismiss()
    }
}

// MARK: - 🏠 Главный Экран

struct ContentView: View {
    @StateObject private var locationManager = LocationManager()
    @StateObject private var apiService = SatelliteAPI()
    @StateObject private var settings = AppSettings()
    @StateObject private var compassManager = CompassManager()
    @State private var selectedSatellite: Satellite?
    @State private var showSettings = false
    
    var visibleCount: Int {
        apiService.satellites.filter { $0.isVisible }.count
    }
    
    var hiddenCount: Int {
        apiService.satellites.filter { !$0.isVisible }.count
    }
    
    var body: some View {
        NavigationView {
            Group {
                if !settings.isConfigured {
                    welcomeView
                } else if !settings.useManualLocation &&
                          (locationManager.authorizationStatus != .authorizedWhenInUse &&
                           locationManager.authorizationStatus != .authorizedAlways) {
                    locationPermissionView
                } else {
                    mainView
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView(settings: settings, locationManager: locationManager)
            }
            .sheet(item: $selectedSatellite) { satellite in
                NavigationView {
                    SatelliteDetailView(satellite: satellite, compassManager: compassManager)
                }
            }
            .onAppear {
                if !settings.useManualLocation {
                    locationManager.requestLocation()
                }
                compassManager.requestHeading()
            }
            .onChange(of: settings.isConfigured) { _ in
                if settings.isConfigured { Task { await refreshData() } }
            }
            .onChange(of: locationManager.currentLocation) { _ in
                if settings.isConfigured && !settings.useManualLocation {
                    Task { await refreshData() }
                }
            }
            .onChange(of: settings.useManualLocation) { _ in
                if settings.isConfigured && settings.useManualLocation {
                    Task { await refreshData() }
                }
            }
        }
    }
    
    private var welcomeView: some View {
        VStack(spacing: 20) {
            Image(systemName: "dish")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            Text("Требуется настройка")
                .font(.title2)
                .fontWeight(.bold)
            Text("Введите API ключ для отслеживания SATCOM спутников")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Button("Перейти в настройки") {
                showSettings = true
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }
    
    private var locationPermissionView: some View {
        VStack(spacing: 20) {
            Image(systemName: "location.slash")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            Text("Нужен доступ к геопозиции")
                .font(.headline)
            Text("Или включите ручные координаты в настройках")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            HStack(spacing: 16) {
                Button("Разрешить GPS") {
                    locationManager.requestLocation()
                }
                .buttonStyle(.borderedProminent)
                
                Button("Ручные координаты") {
                    showSettings = true
                }
                .buttonStyle(.bordered)
            }
        }
    }
    
    private var mainView: some View {
        VStack(spacing: 0) {
            if let lastUpdate = apiService.lastUpdateTime {
                infoBar(lastUpdate: lastUpdate)
            }
            
            HStack {
                Image(systemName: settings.useManualLocation ? "location.slash" : "location.fill")
                    .font(.caption)
                    .foregroundColor(settings.useManualLocation ? .orange : .green)
                Text(settings.useManualLocation ?
                     "Ручные координаты: \(settings.manualLatitude), \(settings.manualLongitude)" :
                     "GPS: \(locationManager.currentLocation?.coordinate.latitude.description ?? "0"), \(locationManager.currentLocation?.coordinate.longitude.description ?? "0")")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 4)
            .background(Color.gray.opacity(0.1))
            
            if !apiService.satellites.isEmpty {
                visibilityIndicator
            }
            
            if apiService.isLoading && apiService.satellites.isEmpty {
                ProgressView("Загрузка данных...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                satelliteList
            }
        }
        .navigationTitle("SATCOM Трекер")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showSettings = true }) {
                    Image(systemName: "gear")
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { Task { await refreshData(force: true) } }) {
                    Image(systemName: "arrow.clockwise")
                        .rotationEffect(apiService.isLoading ? .degrees(360) : .degrees(0))
                        .animation(apiService.isLoading ? .linear(duration: 1) : .default, value: apiService.isLoading)
                }
                .disabled(apiService.isLoading)
            }
        }
    }
    
    private var visibilityIndicator: some View {
        HStack(spacing: 16) {
            HStack(spacing: 4) {
                Image(systemName: "eye.fill")
                    .foregroundColor(.green)
                Text("\(visibleCount)")
                    .fontWeight(.bold)
                    .foregroundColor(.green)
                Text("видимых")
                    .foregroundColor(.secondary)
            }
            
            HStack(spacing: 4) {
                Image(systemName: "eye.slash.fill")
                    .foregroundColor(.red)
                Text("\(hiddenCount)")
                    .fontWeight(.bold)
                    .foregroundColor(.red)
                Text("ниже горизонта")
                    .foregroundColor(.secondary)
            }
        }
        .font(.caption)
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.gray.opacity(0.1))
    }
    
    private func infoBar(lastUpdate: Date) -> some View {
        HStack {
            Image(systemName: "clock")
                .font(.caption)
                .foregroundColor(.secondary)
            Text("Обновлено: \(timeFormatter.string(from: lastUpdate))")
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.caption)
                .foregroundColor(.secondary)
            Text(settings.refreshIntervalText)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.gray.opacity(0.1))
    }
    
    private var satelliteList: some View {
        List {
            if let error = apiService.errorMessage {
                ErrorRow(message: error, onRetry: { Task { await refreshData(force: true) } })
            }
            
            if visibleCount > 0 && hiddenCount > 0 {
                Section {
                    EmptyView()
                } header: {
                    HStack {
                        Image(systemName: "eye.slash.fill")
                            .foregroundColor(.red)
                        Text("Ниже горизонта (\(hiddenCount))")
                            .foregroundColor(.red)
                            .fontWeight(.semibold)
                    }
                }
            }
            
            ForEach(apiService.satellites) { satellite in
                Button(action: { selectedSatellite = satellite }) {
                    SatelliteRow(satellite: satellite)
                }
                .buttonStyle(.plain)
            }
        }
        .listStyle(.plain)
    }
    
    private let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .medium
        return f
    }()
    
    private func refreshData(force: Bool = false) async {
        let latitude: Double
        let longitude: Double
        let altitude: Double
        
        if settings.useManualLocation {
            guard let coords = settings.getCurrentCoordinates() else {
                apiService.errorMessage = "Некорректные ручные координаты"
                return
            }
            latitude = coords.latitude
            longitude = coords.longitude
            altitude = coords.altitude
        } else {
            guard let location = locationManager.currentLocation else {
                return
            }
            latitude = location.coordinate.latitude
            longitude = location.coordinate.longitude
            altitude = location.altitude
        }
        
        await apiService.fetchSatellites(
            apiKey: settings.apiKey,
            noradIDs: settings.allActiveIDs,
            latitude: latitude,
            longitude: longitude,
            altitude: altitude,
            refreshInterval: settings.refreshInterval,
            forceRefresh: force
        )
    }
}

// Вспомогательные Views
struct ErrorRow: View {
    let message: String
    let onRetry: () -> Void
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.orange)
                Text("Ошибка").fontWeight(.bold)
            }
            Text(message).font(.caption).foregroundColor(.secondary).textSelection(.enabled)
            Button("Повторить", action: onRetry).buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity).padding().listRowBackground(Color.clear)
    }
}

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "dish").font(.system(size: 48)).foregroundColor(.gray)
            Text("Нет данных").font(.headline)
            Text("Нажмите кнопку обновления").font(.subheadline).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity).padding()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View { ContentView() }
}
