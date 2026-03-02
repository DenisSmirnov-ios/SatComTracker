import SwiftUI
import CoreLocation
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var settings: AppSettings
    @ObservedObject var locationManager: LocationManager
    @ObservedObject private var libraryStore = SatelliteFrequencyLibraryStore.shared
    
    @State private var satelliteInput = ""
    @State private var showingClearAlert = false
    @State private var showingMapView = false
    @State private var showingTLEImporter = false
    @State private var tleImportStatus: String?
    @State private var showingFrequencyImporter = false
    @State private var frequencyImportStatus: String?
    @State private var pendingFrequencyImportURL: URL?
    @State private var showingFrequencyImportModeSheet = false
    @State private var showingDeleteFrequenciesConfirmSheet = false
    
    @State private var settingsChanged = false
        
    var sortedSatelliteIDs: [Int] {
        settings.allActiveIDs.sorted()
    }
    
    var catalogSuggestions: [CatalogSatellite] {
        let existing = Set(settings.allActiveIDs)
        return SatelliteCatalogLibrary.search(satelliteInput)
            .filter { !existing.contains($0.noradID) }
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("API Ключ")) {
                    TextField("Введите API ключ", text: $settings.apiKey)
                        .textContentType(.password)
                        .autocapitalization(.none)
                        .onChange(of: settings.apiKey) { _ in
                            settingsChanged = true
                        }
                }

                Section(header: Text("Оформление")) {
                    Picker("Тема", selection: Binding(
                        get: { settings.themeMode },
                        set: {
                            settings.themeMode = $0
                            settingsChanged = true
                        }
                    )) {
                        ForEach(AppSettings.ThemeMode.allCases, id: \.self) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                Section(header: Text("Местоположение")) {
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
                
                Section(header: Text("Интервал обновления")) {
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
                
                Section(header: Text("Спутники (NORAD ID)")) {
                    HStack {
                        TextField("NORAD ID или название", text: $satelliteInput)
                            .textInputAutocapitalization(.characters)
                        Button("Добавить") {
                            addSatelliteFromInput()
                        }
                        .disabled(satelliteInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    
                    Button("Импортировать TLE файл") {
                        showingTLEImporter = true
                    }
                    
                    Text("Подсказка: введите NORAD ID (например, 25544) или часть названия (например, GALAXY), затем выберите спутник из списка.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    if !catalogSuggestions.isEmpty {
                        ForEach(catalogSuggestions) { satellite in
                            Button {
                                settings.addCustomID(satellite.noradID)
                                settingsChanged = true
                                satelliteInput = ""
                            } label: {
                                HStack {
                                    Text(satellite.name)
                                        .lineLimit(1)
                                    Spacer()
                                    Text("ID: \(satellite.noradID)")
                                        .foregroundColor(.secondary)
                                        .font(.caption)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    } else if !satelliteInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("Совпадений не найдено")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if let status = tleImportStatus {
                        Text(status)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    if sortedSatelliteIDs.isEmpty {
                        Text("Список пуст. Добавьте NORAD ID вручную или импортируйте TLE.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    ForEach(sortedSatelliteIDs, id: \.self) { id in
                        HStack {
                            Text("ID: \(id)")
                            Spacer()
                            Button(action: {
                                removeSatelliteID(id)
                                settingsChanged = true
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                }
                
                Section(header: Text("Библиотека частот")) {
                    Button("Импортировать данные библиотеки (PDF/XLSX)") {
                        showingFrequencyImporter = true
                    }
                    
                    Button("Удалить все данные частот", role: .destructive) {
                        showingDeleteFrequenciesConfirmSheet = true
                    }
                    
                    if let status = frequencyImportStatus {
                        Text(status)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section {
                    Button("Очистить все спутники", role: .destructive) {
                        showingClearAlert = true
                    }
                }
            }
            .background(AppBackground())
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
            .overlay {
                if showingDeleteFrequenciesConfirmSheet {
                    ZStack {
                        Color.black.opacity(0.55)
                            .ignoresSafeArea()
                            .contentShape(Rectangle())
                        
                        FrequencyDataDeleteConfirmSheet(
                            onConfirm: {
                                clearAllFrequencyData()
                                showingDeleteFrequenciesConfirmSheet = false
                            },
                            onCancel: {
                                showingDeleteFrequenciesConfirmSheet = false
                            }
                        )
                        .frame(maxWidth: 420)
                        .padding(.horizontal, 16)
                    }
                }
            }
            .overlay {
                if showingFrequencyImportModeSheet {
                    ZStack {
                        Color.black.opacity(0.45)
                            .ignoresSafeArea()
                            .contentShape(Rectangle())
                        
                        FrequencyImportModeSheet(
                            onMerge: {
                                executeFrequencyImport(mode: .merge)
                                showingFrequencyImportModeSheet = false
                            },
                            onReplace: {
                                executeFrequencyImport(mode: .replace)
                                showingFrequencyImportModeSheet = false
                            },
                            onCancel: {
                                pendingFrequencyImportURL = nil
                                showingFrequencyImportModeSheet = false
                            }
                        )
                        .frame(maxWidth: 420)
                        .padding(.horizontal, 16)
                    }
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
            .fileImporter(
                isPresented: $showingTLEImporter,
                allowedContentTypes: [.text, .plainText],
                allowsMultipleSelection: false
            ) { result in
                handleTLEImport(result)
            }
            .fileImporter(
                isPresented: $showingFrequencyImporter,
                allowedContentTypes: [.pdf, .xlsx],
                allowsMultipleSelection: false
            ) { result in
                handleFrequencyImport(result)
            }
            .onDisappear {
                if settingsChanged {
                    NotificationCenter.default.post(name: .settingsChanged, object: nil)
                }
            }
        }
    }
    
    private func removeSatelliteID(_ id: Int) {
        settings.noradIDs = settings.noradIDs.filter { $0 != id }
        settings.customIDs = settings.customIDs.filter { $0 != id }
    }
    
    private func addSatelliteFromInput() {
        let query = satelliteInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        
        if let id = Int(query), id > 0 {
            settings.addCustomID(id)
            settingsChanged = true
            satelliteInput = ""
            return
        }
        
        if let exact = catalogSuggestions.first(where: { normalizeSearchText($0.name) == normalizeSearchText(query) }) {
            settings.addCustomID(exact.noradID)
            settingsChanged = true
            satelliteInput = ""
        }
    }
    
    private func normalizeSearchText(_ text: String) -> String {
        text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
    }
    
    private func handleTLEImport(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let error):
            tleImportStatus = "Ошибка импорта: \(error.localizedDescription)"
        case .success(let urls):
            guard let url = urls.first else {
                tleImportStatus = "Файл не выбран"
                return
            }
            importTLE(from: url)
        }
    }
    
    private func importTLE(from url: URL) {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        do {
            let text = try String(contentsOf: url, encoding: .utf8)
            let ids = extractNORADIDs(fromTLEText: text)
            guard !ids.isEmpty else {
                tleImportStatus = "В файле не найдено корректных TLE записей"
                return
            }
            settings.addCustomIDs(ids)
            settingsChanged = true
            tleImportStatus = "Импортировано \(ids.count) спутников из TLE"
        } catch {
            tleImportStatus = "Не удалось прочитать файл: \(error.localizedDescription)"
        }
    }
    
    private func handleFrequencyImport(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let error):
            frequencyImportStatus = "Ошибка импорта частот: \(error.localizedDescription)"
        case .success(let urls):
            guard let url = urls.first else {
                frequencyImportStatus = "Файл частот не выбран"
                return
            }
            pendingFrequencyImportURL = url
            showingFrequencyImportModeSheet = true
        }
    }
    
    private func executeFrequencyImport(mode: SatelliteFrequencyLibraryStore.ImportMode) {
        guard let url = pendingFrequencyImportURL else {
            frequencyImportStatus = "Файл частот не выбран"
            return
        }
        
        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                url.stopAccessingSecurityScopedResource()
            }
            pendingFrequencyImportURL = nil
        }
        
        do {
            let summary = try libraryStore.importFromFile(url: url, mode: mode)
            let modeText = summary.mode == .replace ? "Полная замена" : "Объединение"
            frequencyImportStatus = "\(modeText): добавлено \(summary.addedRows), дубликатов \(summary.duplicateRows), спутников \(summary.satellitesAffected)"
        } catch {
            frequencyImportStatus = "Не удалось импортировать частоты: \(error.localizedDescription)"
        }
    }
    
    private func clearAllFrequencyData() {
        libraryStore.clearAllData()
        SatelliteFrequencyStateStore.shared.clearAll()
        frequencyImportStatus = "Все данные частот удалены"
    }
    
    private func extractNORADIDs(fromTLEText text: String) -> [Int] {
        let lines = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        var ids = Set<Int>()
        var index = 0
        
        while index < lines.count {
            let line = lines[index]
            if line.hasPrefix("1 "), let id = extractNORADID(fromLine1: line) {
                ids.insert(id)
                index += 1
                continue
            }
            
            // 3-строчный TLE: NAME, line1, line2
            if index + 1 < lines.count,
               lines[index + 1].hasPrefix("1 "),
               let id = extractNORADID(fromLine1: lines[index + 1]) {
                ids.insert(id)
                index += 2
                continue
            }
            
            index += 1
        }
        
        return Array(ids).sorted()
    }
    
    private func extractNORADID(fromLine1 line: String) -> Int? {
        let parts = line.split(whereSeparator: { $0.isWhitespace })
        guard parts.count > 1 else { return nil }
        
        let token = String(parts[1])
        let digits = token.prefix { $0.isNumber }
        guard !digits.isEmpty else { return nil }
        
        return Int(digits)
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

            if let gpsStatus = gpsStatusMessage {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: gpsStatus.isError ? "location.slash.fill" : "checkmark.circle.fill")
                        .foregroundColor(gpsStatus.isError ? .red : .green)
                        .padding(.top, 2)
                    Text(gpsStatus.message)
                        .font(.caption2)
                        .foregroundColor(gpsStatus.isError ? .red : .secondary)
                        .multilineTextAlignment(.leading)
                    Spacer()
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(gpsStatus.isError ? Color.red.opacity(0.12) : Color.green.opacity(0.10))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(gpsStatus.isError ? Color.red.opacity(0.28) : Color.green.opacity(0.24), lineWidth: 1)
                )
            }
            
            Text(settings.locationSource.description)
                .font(.caption2)
                .foregroundColor(.secondary)
                .padding(.top, 4)
        }
        .padding(.vertical, 4)
    }

    private var gpsStatusMessage: (message: String, isError: Bool)? {
        if locationManager.currentLocation != nil {
            return ("GPS работает стабильно. Координаты успешно получены.", false)
        }

        if let error = locationManager.locationError, !error.isEmpty {
            return ("Ошибка GPS: \(error). Проверьте сигнал и попробуйте на открытом месте.", true)
        }

        if !locationManager.hasPermission {
            switch locationManager.authorizationStatus {
            case .denied, .restricted:
                return ("GPS отключен для приложения. Включите доступ к геопозиции в настройках телефона.", true)
            case .notDetermined:
                return ("Разрешение GPS еще не выдано. Нажмите «Разрешить доступ».", true)
            default:
                return ("GPS недоступен. Проверьте настройки геолокации.", true)
            }
        }

        return ("Ожидание сигнала GPS. Если координаты не появятся, проверьте интернет и геолокацию.", true)
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

private extension UTType {
    static var xlsx: UTType {
        UTType(filenameExtension: "xlsx") ?? .data
    }
}

private struct FrequencyDataDeleteConfirmSheet: View {
    let onConfirm: () -> Void
    let onCancel: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    @State private var offsetX: CGFloat = 0
    @State private var offsetY: CGFloat = 0
    private let knobSize: CGFloat = 52
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.red.opacity(0.10), Color.orange.opacity(0.08), Color.clear],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 18) {
                ZStack {
                    Circle()
                        .fill(Color.red.opacity(0.14))
                        .frame(width: 70, height: 70)
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundColor(.red)
                }
                
                VStack(spacing: 8) {
                    Text("Вы точно уверены?")
                        .font(.title3)
                        .fontWeight(.bold)
                    
                    Text("Все данные о частотах будут уничтожены без возможности восстановления.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Label("Удалится предустановленная библиотека частот", systemImage: "trash")
                    Label("Удалятся данные, добавленные пользователем", systemImage: "person.crop.circle.badge.xmark")
                    Label("Удалятся комментарии и статусы каналов", systemImage: "bubble.left.and.exclamationmark.bubble.right")
                }
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(UITheme.surfaceBackground(for: colorScheme).opacity(0.85))
                .cornerRadius(12)
                
                GeometryReader { geometry in
                    let trackWidth = min(geometry.size.width, 360)
                    let maxOffset = trackWidth - knobSize
                    
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 28)
                            .fill(Color.red.opacity(0.14))
                            .frame(width: trackWidth, height: 56)
                        
                        Text("Да, удалить все данные!")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.red)
                            .frame(width: trackWidth, height: 56)
                        
                        Circle()
                            .fill(Color.red)
                            .frame(width: knobSize, height: knobSize)
                            .overlay(
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.white)
                                    .font(.headline)
                            )
                            .offset(x: offsetX)
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        offsetX = max(0, min(value.translation.width, maxOffset))
                                    }
                                    .onEnded { _ in
                                        if offsetX >= maxOffset * 0.88 {
                                            onConfirm()
                                        } else {
                                            withAnimation(.easeOut(duration: 0.2)) {
                                                offsetX = 0
                                            }
                                        }
                                    }
                            )
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                }
                .frame(height: 56)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(UITheme.surfaceBackground(for: colorScheme))
            )
            .shadow(color: .black.opacity(0.2), radius: 20, y: 10)
            .offset(y: offsetY)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        offsetY = value.translation.height
                    }
                    .onEnded { value in
                        if abs(value.translation.height) > 100 {
                            onCancel()
                        } else {
                            withAnimation(.easeOut(duration: 0.2)) {
                                offsetY = 0
                            }
                        }
                    }
            )
        }
    }
}

private struct FrequencyImportModeSheet: View {
    let onMerge: () -> Void
    let onReplace: () -> Void
    let onCancel: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Spacer()
                Button("Отмена") { onCancel() }
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
            }
            
            Image(systemName: "tray.and.arrow.down.fill")
                .font(.system(size: 30, weight: .semibold))
                .foregroundColor(UITheme.accent)
            
            Text("Как обновить библиотеку?")
                .font(.title3)
                .fontWeight(.bold)
            
            Text("Выберите, как применить данные из выбранного файла частот.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button {
                onMerge()
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Объединить данные библиотеки")
                        .font(.headline)
                    Text("Добавить новые частоты, дубликаты не трогать")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(UITheme.accent.opacity(0.10))
                .cornerRadius(12)
            }
            .buttonStyle(.plain)
            
            Button {
                onReplace()
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Полностью заменить библиотеку")
                        .font(.headline)
                        .foregroundColor(.orange)
                    Text("Стереть текущие данные и загрузить только из файла")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Color.orange.opacity(0.10))
                .cornerRadius(12)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(UITheme.surfaceBackground(for: colorScheme))
        )
        .shadow(color: .black.opacity(0.2), radius: 20, y: 10)
    }
}
