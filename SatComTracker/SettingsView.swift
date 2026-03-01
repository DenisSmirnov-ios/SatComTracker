import SwiftUI
import CoreLocation

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var settings: AppSettings
    @ObservedObject var locationManager: LocationManager
    
    @State private var searchText = ""
    @State private var newCustomID = ""
    @State private var showingClearAlert = false
    @State private var showingMapView = false
    
    @State private var settingsChanged = false
    
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
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("🔑 API Ключ")) {
                    TextField("Введите API ключ", text: $settings.apiKey)
                        .textContentType(.password)
                        .autocapitalization(.none)
                        .onChange(of: settings.apiKey) { _ in
                            settingsChanged = true
                        }
                }
                
                Section(header: Text("📍 Местоположение")) {
                    Picker("Источник", selection: $settings.locationSource) {
                        ForEach(AppSettings.LocationSource.allCases, id: \.self) { source in
                            Label(source.rawValue, systemImage: source.icon).tag(source)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: settings.locationSource) { _ in
                        settingsChanged = true
                    }
                    
                    switch settings.locationSource {
                    case .gps:
                        gpsLocationView
                    case .manual:
                        manualLocationView
                    case .map:
                        mapLocationView
                    }
                }
                
                Section(header: Text("🔄 Интервал обновления")) {
                    Picker("Интервал", selection: $settings.refreshInterval) {
                        Text("5 мин").tag(300)
                        Text("15 мин").tag(900)
                        Text("30 мин").tag(1800)
                        Text("1 час").tag(3600)
                        Text("2 часа").tag(7200)
                        Text("4 часа").tag(14400)
                    }
                    .pickerStyle(.menu)
                    .onChange(of: settings.refreshInterval) { _ in
                        settingsChanged = true
                    }
                    
                    if settings.refreshInterval < 3600 {
                        Text("⚠️ Может превысить лимит API")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    
                    if settings.lastCacheUpdate != Date.distantPast {
                        HStack {
                            Text("Последнее обновление:")
                                .font(.caption2)
                            Spacer()
                            Text(settings.lastCacheUpdate, style: .time)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Section(header: Text("📡 Спутники (из файла частот)")) {
                    TextField("Поиск...", text: $searchText)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: searchText) { _ in
                            settingsChanged = true
                        }
                    
                    ForEach(filteredSatellites) { sat in
                        HStack {
                            Image(systemName: settings.isSatelliteSelected(sat.noradID) ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(settings.isSatelliteSelected(sat.noradID) ? .green : .gray)
                            
                            VStack(alignment: .leading) {
                                Text(sat.name)
                                    .font(.subheadline)
                                HStack {
                                    Text("\(sat.noradID) • \(sat.category)")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    if sat.defaultChannels > 0 {
                                        Text("📡 \(sat.defaultChannels) каналов")
                                            .font(.caption2)
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                            
                            Spacer()
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            settings.toggleSatellite(sat.noradID)
                            settingsChanged = true
                        }
                    }
                }
                
                Section(header: Text("➕ Пользовательские ID")) {
                    HStack {
                        TextField("NORAD ID", text: $newCustomID)
                            .keyboardType(.numberPad)
                        Button("Добавить") {
                            if let id = Int(newCustomID), id > 0 {
                                settings.addCustomID(id)
                                newCustomID = ""
                                settingsChanged = true
                            }
                        }
                        .disabled(newCustomID.isEmpty)
                    }
                    
                    ForEach(settings.customIDs, id: \.self) { id in
                        HStack {
                            Text("ID: \(id)")
                            Spacer()
                            Button(action: {
                                settings.removeCustomID(id)
                                settingsChanged = true
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                }
                
                Section {
                    Button("Выбрать все спутники") {
                        settings.selectAllSatellites()
                        settingsChanged = true
                    }
                    
                    Button("Очистить все спутники", role: .destructive) {
                        showingClearAlert = true
                    }
                    
                    Button("🗑 Очистить все частоты", role: .destructive) {
                        FrequencyStore.shared.clearAll()
                    }
                }
            }
            .navigationTitle("Настройки")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Готово") {
                        dismiss()
                    }
                }
            }
            .alert("Очистить все спутники?", isPresented: $showingClearAlert) {
                Button("Отмена", role: .cancel) { }
                Button("Очистить", role: .destructive) {
                    settings.clearAllSatellites()
                    settingsChanged = true
                }
            }
            .onChange(of: settings.locationSource) { newSource in
                switch newSource {
                case .gps:
                    locationManager.startUpdating()
                case .manual, .map:
                    locationManager.stopUpdating()
                }
            }
            .sheet(isPresented: $showingMapView) {
                MapLocationView(settings: settings, locationManager: locationManager)
            }
            .onDisappear {
                if settingsChanged {
                    NotificationCenter.default.post(name: .settingsChanged, object: nil)
                }
            }
        }
    }
    
    @ViewBuilder
    private var gpsLocationView: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !locationManager.hasPermission {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("Нет доступа к GPS")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                
                Button("Разрешить доступ") {
                    locationManager.requestLocation()
                }
                .font(.caption)
                .buttonStyle(.bordered)
            } else if let location = locationManager.currentLocation {
                HStack {
                    Image(systemName: "location.fill")
                        .foregroundColor(.green)
                    Text("Текущие координаты:")
                        .font(.caption)
                }
                
                HStack {
                    Text(String(format: "Ш: %.4f°", location.coordinate.latitude))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(String(format: "Д: %.4f°", location.coordinate.longitude))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(6)
            } else {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Определение местоположения...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if let error = locationManager.locationError {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }
            
            Text(settings.locationSource.description)
                .font(.caption2)
                .foregroundColor(.secondary)
                .padding(.top, 4)
        }
        .padding(.vertical, 4)
    }
    
    @ViewBuilder
    private var manualLocationView: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Широта:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 60, alignment: .leading)
                TextField("55.7558", text: $settings.manualLatitude)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                    .font(.caption)
                    .onChange(of: settings.manualLatitude) { _ in
                        settingsChanged = true
                    }
            }
            
            HStack {
                Text("Долгота:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 60, alignment: .leading)
                TextField("37.6173", text: $settings.manualLongitude)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                    .font(.caption)
                    .onChange(of: settings.manualLongitude) { _ in
                        settingsChanged = true
                    }
            }
            
            if let lat = Double(settings.manualLatitude),
               let lon = Double(settings.manualLongitude),
               abs(lat) <= 90, abs(lon) <= 180 {
                HStack {
                    Spacer()
                    Label("Корректные координаты", systemImage: "checkmark.circle.fill")
                        .font(.caption2)
                        .foregroundColor(.green)
                }
            } else {
                HStack {
                    Spacer()
                    Label("Некорректные координаты", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
            }
            
            Text(settings.locationSource.description)
                .font(.caption2)
                .foregroundColor(.secondary)
                .padding(.top, 4)
        }
        .padding(.vertical, 4)
    }
    
    @ViewBuilder
    private var mapLocationView: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let lat = Double(settings.manualLatitude),
               let lon = Double(settings.manualLongitude) {
                HStack {
                    Image(systemName: "mappin.circle.fill")
                        .foregroundColor(.red)
                    Text("Выбрано на карте:")
                        .font(.caption)
                }
                
                HStack {
                    Text(String(format: "Ш: %.4f°", lat))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(String(format: "Д: %.4f°", lon))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(6)
                
                if !settings.lastSelectedAddress.isEmpty {
                    Text(settings.lastSelectedAddress)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            } else {
                Text("Координаты не выбраны")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Button("Открыть карту") {
                showingMapView = true
            }
            .font(.caption)
            .buttonStyle(.bordered)
            .padding(.top, 4)
            
            Text(settings.locationSource.description)
                .font(.caption2)
                .foregroundColor(.secondary)
                .padding(.top, 4)
        }
        .padding(.vertical, 4)
    }
}
