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

// MARK: - 💾 Хранилище частот (Обновлённое - множественные каналы)

class FrequencyStore: ObservableObject {
    static let shared = FrequencyStore()
    
    @Published var frequencies: [Int: SatelliteFrequencies] = [:]
    
    struct CommunicationChannel: Codable, Identifiable {
        let id: UUID
        var name: String
        var rxFrequency: String
        var txFrequency: String
        var notes: String
        var createdAt: Date
        
        init(id: UUID = UUID(), name: String = "", rxFrequency: String = "", txFrequency: String = "", notes: String = "", createdAt: Date = Date()) {
            self.id = id
            self.name = name
            self.rxFrequency = rxFrequency
            self.txFrequency = txFrequency
            self.notes = notes
            self.createdAt = createdAt
        }
    }
    
    struct SatelliteFrequencies: Codable {
        var channels: [CommunicationChannel]
        
        init(channels: [CommunicationChannel] = []) {
            self.channels = channels
        }
    }
    
    private let storageKey = "satelliteFrequencies"
    
    init() {
        loadFrequencies()
    }
    
    func loadFrequencies() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([Int: SatelliteFrequencies].self, from: data) {
            frequencies = decoded
            objectWillChange.send()
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
    
    func addChannel(for satId: Int, channel: CommunicationChannel) {
        var freqs = getFrequencies(for: satId)
        freqs.channels.append(channel)
        saveFrequencies(for: satId, frequencies: freqs)
    }
    
    func updateChannel(for satId: Int, channel: CommunicationChannel) {
        var freqs = getFrequencies(for: satId)
        if let index = freqs.channels.firstIndex(where: { $0.id == channel.id }) {
            freqs.channels[index] = channel
            saveFrequencies(for: satId, frequencies: freqs)
        }
    }
    
    func deleteChannel(for satId: Int, channelId: UUID) {
        var freqs = getFrequencies(for: satId)
        freqs.channels.removeAll { $0.id == channelId }
        saveFrequencies(for: satId, frequencies: freqs)
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
                
                results.append(Satellite(
                    id: result.info.satid,
                    name: result.info.satname,
                    azimuth: pos.azimuth,
                    elevation: pos.elevation,
                    distanceKm: distance,
                    velocity: 27600,
                    timestamp: Date(timeIntervalSince1970: pos.timestamp),
                    isError: false
                ))
                
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

// ✅ Экран редактирования каналов связи (Обновлённый)
struct FrequencyEditView: View {
    let satelliteId: Int
    let satelliteName: String
    @ObservedObject var frequencyStore = FrequencyStore.shared
    @Environment(\.dismiss) var dismiss
    
    @State private var channels: [FrequencyStore.CommunicationChannel] = []
    @State private var showingAddChannel = false
    @State private var editingChannel: FrequencyStore.CommunicationChannel?
    
    init(satelliteId: Int, satelliteName: String) {
        self.satelliteId = satelliteId
        self.satelliteName = satelliteName
    }
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("📡 Каналы связи (\(channels.count))")) {
                    if channels.isEmpty {
                        Text("Нет сохранённых каналов")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    } else {
                        ForEach(channels) { channel in
                            ChannelRow(channel: channel)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    editingChannel = channel
                                }
                        }
                        .onDelete { offsets in
                            for index in offsets {
                                frequencyStore.deleteChannel(for: satelliteId, channelId: channels[index].id)
                            }
                            channels = frequencyStore.getFrequencies(for: satelliteId).channels
                        }
                    }
                }
                
                Section {
                    Button(action: { showingAddChannel = true }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.blue)
                            Text("Добавить канал")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle(satelliteName)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Готово") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        frequencyStore.clearFrequencies()
                        channels = []
                    }) {
                        Text("Очистить все")
                            .foregroundColor(.red)
                    }
                }
            }
            .sheet(isPresented: $showingAddChannel) {
                ChannelEditView(satelliteId: satelliteId, channel: nil, onSave: {
                    channels = frequencyStore.getFrequencies(for: satelliteId).channels
                })
            }
            .sheet(item: $editingChannel) { channel in
                ChannelEditView(satelliteId: satelliteId, channel: channel, onSave: {
                    channels = frequencyStore.getFrequencies(for: satelliteId).channels
                })
            }
            .onAppear {
                channels = frequencyStore.getFrequencies(for: satelliteId).channels
            }
        }
    }
}

// ✅ Строка канала связи
struct ChannelRow: View {
    let channel: FrequencyStore.CommunicationChannel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "radio")
                    .foregroundColor(.blue)
                Text(channel.name.isEmpty ? "Без названия" : channel.name)
                    .fontWeight(.semibold)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("RX")
                        .font(.caption2)
                        .foregroundColor(.green)
                    Text(channel.rxFrequency.isEmpty ? "—" : channel.rxFrequency)
                        .font(.system(.caption, design: .monospaced))
                        .fontWeight(.medium)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("TX")
                        .font(.caption2)
                        .foregroundColor(.orange)
                    Text(channel.txFrequency.isEmpty ? "—" : channel.txFrequency)
                        .font(.system(.caption, design: .monospaced))
                        .fontWeight(.medium)
                }
            }
            .padding(.vertical, 2)
            
            if !channel.notes.isEmpty {
                Text(channel.notes)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }
}

// ✅ Экран редактирования канала
struct ChannelEditView: View {
    let satelliteId: Int
    let channel: FrequencyStore.CommunicationChannel?
    let onSave: () -> Void
    
    @Environment(\.dismiss) var dismiss
    @ObservedObject var frequencyStore = FrequencyStore.shared
    
    @State private var name: String = ""
    @State private var rxFrequency: String = ""
    @State private var txFrequency: String = ""
    @State private var notes: String = ""
    
    init(satelliteId: Int, channel: FrequencyStore.CommunicationChannel?, onSave: @escaping () -> Void) {
        self.satelliteId = satelliteId
        self.channel = channel
        self.onSave = onSave
        
        if let channel = channel {
            _name = State(initialValue: channel.name)
            _rxFrequency = State(initialValue: channel.rxFrequency)
            _txFrequency = State(initialValue: channel.txFrequency)
            _notes = State(initialValue: channel.notes)
        }
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("📝 Название канала")) {
                    TextField("Например: Основной, Резервный, Данные", text: $name)
                }
                
                Section(header: Text("📡 Частоты")) {
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
                
                Section(header: Text("📝 Заметки")) {
                    TextEditor(text: $notes)
                        .frame(minHeight: 80)
                }
                
                Section {
                    Button(channel == nil ? "💾 Добавить канал" : "💾 Сохранить изменения") {
                        saveChannel()
                    }
                    .frame(maxWidth: .infinity)
                    .disabled(name.isEmpty && rxFrequency.isEmpty && txFrequency.isEmpty)
                    
                    if channel != nil {
                        Button("🗑 Удалить канал", role: .destructive) {
                            if let channel = channel {
                                frequencyStore.deleteChannel(for: satelliteId, channelId: channel.id)
                                onSave()
                                dismiss()
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .navigationTitle(channel == nil ? "Новый канал" : "Редактировать канал")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Отмена") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func saveChannel() {
        if let existingChannel = channel {
            var updatedChannel = existingChannel
            updatedChannel.name = name
            updatedChannel.rxFrequency = rxFrequency
            updatedChannel.txFrequency = txFrequency
            updatedChannel.notes = notes
            frequencyStore.updateChannel(for: satelliteId, channel: updatedChannel)
        } else {
            let newChannel = FrequencyStore.CommunicationChannel(
                name: name,
                rxFrequency: rxFrequency,
                txFrequency: txFrequency,
                notes: notes
            )
            frequencyStore.addChannel(for: satelliteId, channel: newChannel)
        }
        onSave()
        dismiss()
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
                        Text("🧭 Как найти спутник")
                            .font(.headline)
                        Spacer()
                        Image(systemName: compassManager.isCalibrating ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                            .foregroundColor(compassManager.isCalibrating ? .orange : .green)
                    }
                    
                    ActiveCompassView(
                        satelliteAzimuth: satellite.azimuth,
                        compassManager: compassManager
                    )
                    
                    VStack(alignment: .leading, spacing: 10) {
                        Text("📍 Пошаговая инструкция:")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("1.")
                                        .fontWeight(.bold)
                                        .foregroundColor(.blue)
                                    Text("Встаньте лицом на Север")
                                }
                                
                                HStack {
                                    Text("2.")
                                        .fontWeight(.bold)
                                        .foregroundColor(.blue)
                                    Text(String(format: "Повернитесь вправо на %.0f°", satellite.azimuth))
                                }
                                
                                HStack {
                                    Text("3.")
                                        .fontWeight(.bold)
                                        .foregroundColor(.blue)
                                    Text(String(format: "Поднимите взгляд на %.0f°", satellite.elevation))
                                }
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 8) {
                                Label("Азимут", systemImage: "compass")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(String(format: "%.0f°", satellite.azimuth))
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.blue)
                                
                                Label("Элевация", systemImage: "angle")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(String(format: "%.0f°", satellite.elevation))
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.green)
                            }
                        }
                        
                        Divider()
                        
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 8) {
                                Image(systemName: "iphone")
                                    .foregroundColor(.blue)
                                Text("Держите телефон горизонтально для точного компаса")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            HStack(spacing: 8) {
                                Image(systemName: "location.fill")
                                    .foregroundColor(.green)
                                Text("Красная стрелка показывает направление на спутник")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            HStack(spacing: 8) {
                                Image(systemName: "eye")
                                    .foregroundColor(.purple)
                                Text("Спутник будет в точке, куда указывает стрелка")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(8)
                        .background(Color.blue.opacity(0.05))
                        .cornerRadius(8)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.05), radius: 3, y: 2)
                    
                    VStack(spacing: 4) {
                        Text(String(format: """
                        Текущий курс: %.0f° | Нужно повернуть: %.0f°
                        """,
                            compassManager.magneticHeading,
                            (satellite.azimuth - compassManager.magneticHeading + 360).truncatingRemainder(dividingBy: 360)
                        ))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        
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
                DataCard(title: "Элевация", value: String(format: "%.1f°", satellite.elevation), icon: "angle", isNegative: !satellite.isVisible)
                DataCard(title: "Расстояние", value: String(format: "%.0f км", satellite.distanceKm), icon: "ruler")
                DataCard(title: "Скорость", value: String(format: "%.0f км/ч", satellite.velocity), icon: "gauge")
                DataCard(title: "Время данных", value: timeFormatter.string(from: satellite.timestamp), icon: "clock")
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(16)
    }
    
    private var frequencySection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("📡 Каналы связи")
                    .font(.headline)
                Spacer()
                Button(action: { showFrequencyEdit = true }) {
                    Image(systemName: "pencil.circle")
                        .foregroundColor(.blue)
                }
            }
            
            let freqs = frequencyStore.getFrequencies(for: satellite.id)
            
            if freqs.channels.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "antenna.radiowaves.left.and.right.slash")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                    Text("Нет сохранённых каналов")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("Нажмите на иконку антенны чтобы добавить RX/TX частоты")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
            } else {
                VStack(spacing: 8) {
                    ForEach(freqs.channels.prefix(3)) { channel in
                        MiniChannelCard(channel: channel)
                    }
                    
                    if freqs.channels.count > 3 {
                        Text("Ещё каналов: \(freqs.channels.count - 3)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

// ✅ Мини-карточка канала
struct MiniChannelCard: View {
    let channel: FrequencyStore.CommunicationChannel
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(channel.name.isEmpty ? "Без названия" : channel.name)
                    .font(.caption)
                    .fontWeight(.semibold)
                HStack(spacing: 8) {
                    Label(channel.rxFrequency.isEmpty ? "RX: —" : "RX: \(channel.rxFrequency)", systemImage: "arrow.down.circle")
                        .font(.caption2)
                        .foregroundColor(.green)
                    Label(channel.txFrequency.isEmpty ? "TX: —" : "TX: \(channel.txFrequency)", systemImage: "arrow.up.circle")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
            }
            Spacer()
        }
        .padding(10)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
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
                Text("У вас есть несохранённые изменения.")
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
            TextField("Введите API ключ", text: $tempAPIKey)
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
                }
                
                HStack {
                    Text("Долгота:")
                        .foregroundColor(.secondary)
                    TextField("37.6173", text: $tempManualLongitude)
                        .keyboardType(.decimalPad)
                }
            }
        } header: {
            Text("📍 Местоположение")
        } footer: {
            Text(tempUseManualLocation ? "Ручные координаты" : "GPS координаты")
        }
    }
    
    private var satellitesSection: some View {
        Section {
            TextField("Поиск спутника...", text: $searchText)
                .textFieldStyle(.roundedBorder)
            
            ForEach(filteredSatellites) { sat in
                SatcomToggleRow(
                    satellite: sat,
                    isSelected: settings.isSatelliteSelected(sat.noradID),
                    onToggle: {
                        settings.toggleSatellite(sat.noradID)
                    }
                )
            }
        } header: {
            Text("📡 Спутники")
        } footer: {
            Text("Нажмите чтобы добавить/удалить")
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
        } header: {
            Text("➕ Пользовательские ID")
        } footer: {
            Text("Добавьте свои спутники")
        }
    }
    
    private var refreshSection: some View {
        Section {
            Picker("Интервал", selection: $tempRefreshInterval) {
                Text("5 минут").tag(300)
                Text("15 минут").tag(900)
                Text("30 минут").tag(1800)
                Text("1 час").tag(3600)
                Text("2 часа").tag(7200)
                Text("4 часа").tag(14400)
            }
            .pickerStyle(.menu)
        } header: {
            Text("🔄 Обновление")
        } footer: {
            Text(warningText)
        }
    }
    
    private var actionSection: some View {
        Section {
            Button(hasUnsavedChanges ? "Сохранить*" : "Сохранить") {
                if tempRefreshInterval != settings.refreshInterval && tempRefreshInterval < 3600 {
                    showWarning = true
                } else {
                    saveSettings()
                }
            }
            .frame(maxWidth: .infinity)
            .disabled(tempAPIKey.isEmpty)
            
            Button("🗑 Очистить все частоты", role: .destructive) {
                FrequencyStore.shared.clearFrequencies()
            }
            .frame(maxWidth: .infinity)
        } header: {
            Text("💾 Частоты")
        } footer: {
            Text("Удалить все каналы связи")
        }
    }
    
    private var warningText: String {
        if tempRefreshInterval < 3600 {
            return "⚠️ При интервале менее 1 часа вы можете превысить лимит API"
        }
        return "Данные кешируются"
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
            }
            
            HStack(spacing: 4) {
                Image(systemName: "eye.slash.fill")
                    .foregroundColor(.red)
                Text("\(hiddenCount)")
                    .fontWeight(.bold)
                    .foregroundColor(.red)
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
            Text("Обновлено: \(lastUpdate, formatter: timeFormatter)")
                .font(.caption)
            Spacer()
            Text(settings.refreshIntervalText)
                .font(.caption)
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

struct ErrorRow: View {
    let message: String
    let onRetry: () -> Void
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.orange)
                Text("Ошибка").fontWeight(.bold)
            }
            Text(message).font(.caption).foregroundColor(.secondary)
            Button("Повторить", action: onRetry).buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity).padding().listRowBackground(Color.clear)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View { ContentView() }
}
