import SwiftUI
import CoreLocation
import UniformTypeIdentifiers
import UIKit

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var settings: AppSettings
    @ObservedObject var locationManager: LocationManager
    @ObservedObject private var libraryStore = SatelliteFrequencyLibraryStore.shared
    
    @State private var satelliteInput = ""
    @State private var showingMapView = false
    @State private var libraryStatus: String?
    @State private var txtTransferStatus: String?
    @State private var showingDeleteFrequenciesConfirmSheet = false
    @State private var activeDocumentPicker: DocumentPickerKind?
    @State private var txtExportURL: URL?
    @State private var showingTXTShareSheet = false
    @State private var isSyncingGitHubFrequencies = false
    @State private var pendingTXTImport: PendingTXTImport?
    @State private var showingGitHubSyncConfirmSheet = false
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var settingsChanged = false
    @State private var githubSyncStatus: String?

    private enum TXTImportMode {
        case merge
        case replace
    }

    private struct PendingTXTImport {
        let byNorad: [Int: [SatelliteFrequencyItem]]
        let statesBySatellite: [Int: [String: SatelliteFrequencyStateStore.FrequencyState]]
        let importedRows: Int
        let skippedRows: Int
        let reasons: [String]
        let satellitesCount: Int
    }

    private enum DocumentPickerKind: Identifiable {
        case channelsTXT

        var id: String {
            switch self {
            case .channelsTXT: return "channels-txt"
            }
        }

        var contentTypes: [UTType] {
            switch self {
            case .channelsTXT:
                return [.plainText, .utf8PlainText, .text]
            }
        }
    }

    var sortedSatelliteIDs: [Int] {
        settings.allActiveIDs.sorted()
    }
    
    var catalogSuggestions: [CatalogSatellite] {
        let existing = Set(settings.allActiveIDs)
        return libraryStore.searchCatalog(satelliteInput)
            .filter { !existing.contains($0.noradID) }
    }

    var estimatedPositionsRequestsPerHour: Double {
        guard settings.refreshInterval > 0 else { return 0 }
        return Double(settings.allActiveIDs.count) * (3600.0 / Double(settings.refreshInterval))
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

                    Text("Получите API-ключ на сайте N2YO (раздел API) и вставьте его сюда. Без ключа обновление данных по спутникам будет недоступно.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
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
                    Picker("Режим обновления", selection: Binding(
                        get: { settings.updateMode },
                        set: {
                            settings.updateMode = $0
                            settingsChanged = true
                        }
                    )) {
                        ForEach(AppSettings.UpdateMode.allCases, id: \.self) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.menu)

                    Picker("Интервал", selection: $settings.refreshInterval) {
                        Text("5 мин").tag(300)
                        Text("15 мин").tag(900)
                        Text("30 мин").tag(1800)
                        Text("1 час").tag(3600)
                        Text("2 часа").tag(7200)
                        Text("4 часа").tag(14400)
                    }
                    .pickerStyle(.menu)
                    .disabled(settings.updateMode != .automatic)
                    .onChange(of: settings.refreshInterval) { _ in
                        settingsChanged = true
                    }
                    
                    if settings.updateMode == .automatic && estimatedPositionsRequestsPerHour > 1000 {
                        Text("⚠️ Нагрузка: ~\(Int(estimatedPositionsRequestsPerHour)) запросов positions/час. Это выше лимита N2YO (1000 за 60 минут).")
                            .font(.caption)
                            .foregroundColor(.red)
                    } else if settings.updateMode == .automatic && estimatedPositionsRequestsPerHour > 800 {
                        Text("⚠️ Нагрузка: ~\(Int(estimatedPositionsRequestsPerHour)) запросов positions/час. Вы близко к лимиту N2YO.")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    
                    if settings.lastCacheUpdate != Date.distantPast {
                        HStack {
                            Text("Последнее обновление данных:")
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
                        TextField("Введите NORAD ID", text: $satelliteInput)
                            .textInputAutocapitalization(.characters)
                        Button("Добавить") {
                            addSatelliteFromInput()
                        }
                        .disabled(satelliteInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }

                    Text("Введите NORAD ID и нажмите «Добавить».")
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
                        Text("Ничего не найдено")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if sortedSatelliteIDs.isEmpty {
                        Text("Список пуст. Добавьте спутник по NORAD ID.")
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
                    Button {
                        showingGitHubSyncConfirmSheet = true
                    } label: {
                        if isSyncingGitHubFrequencies {
                            HStack(spacing: 8) {
                                ProgressView()
                                Text("Синхронизация с GitHub...")
                            }
                        } else {
                            Text("Обновить библиотеку с GitHub")
                        }
                    }
                    .disabled(isSyncingGitHubFrequencies)
                    Text("Обновляет базовую библиотеку с GitHub. Текущая библиотека будет перезаписана.")
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    Button("Скачать библиотеку (TXT)") {
                        exportLibraryTXT()
                    }
                    Text("Сохраняет текущую библиотеку в TXT для резервной копии или ручного редактирования.")
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    Button("Загрузить библиотеку (TXT)") {
                        activeDocumentPicker = .channelsTXT
                    }
                    Text("Проверяет TXT и предлагает: дополнить текущие данные или полностью заменить библиотеку.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Button("Удалить все данные", role: .destructive) {
                        showingDeleteFrequenciesConfirmSheet = true
                    }
                    Text("Полностью очищает спутники, библиотеку частот, кэш и пользовательские пометки.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    if let status = libraryStatus {
                        Text(status)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    if let githubSyncStatus {
                        Text(githubSyncStatus)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    if let txtTransferStatus {
                        Text(txtTransferStatus)
                            .font(.caption2)
                            .foregroundColor(.secondary)
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
            .overlay {
                if showingDeleteFrequenciesConfirmSheet || pendingTXTImport != nil || showingGitHubSyncConfirmSheet {
                    ZStack {
                        Color.black.opacity(0.55)
                            .ignoresSafeArea()
                            .contentShape(Rectangle())

                        if showingDeleteFrequenciesConfirmSheet {
                            FrequencyDataDeleteConfirmSheet(
                                onConfirm: {
                                    clearAllAppData()
                                    showingDeleteFrequenciesConfirmSheet = false
                                },
                                onCancel: {
                                    showingDeleteFrequenciesConfirmSheet = false
                                }
                            )
                            .frame(maxWidth: 420)
                            .padding(.horizontal, 16)
                        } else if showingGitHubSyncConfirmSheet {
                            FrequencyLibrarySyncConfirmSheet(
                                onConfirm: {
                                    showingGitHubSyncConfirmSheet = false
                                    Task { await syncFrequenciesFromGitHub() }
                                },
                                onCancel: {
                                    showingGitHubSyncConfirmSheet = false
                                }
                            )
                            .frame(maxWidth: 420)
                            .padding(.horizontal, 16)
                        } else if let pendingTXTImport {
                            FrequencyTXTImportModeSheet(
                                importedRows: pendingTXTImport.importedRows,
                                satellitesCount: pendingTXTImport.satellitesCount,
                                onMerge: {
                                    applyParsedTXTImport(pendingTXTImport, mode: .merge)
                                    self.pendingTXTImport = nil
                                },
                                onReplace: {
                                    applyParsedTXTImport(pendingTXTImport, mode: .replace)
                                    self.pendingTXTImport = nil
                                },
                                onCancel: {
                                    self.pendingTXTImport = nil
                                    txtTransferStatus = "Импорт TXT отменен пользователем"
                                }
                            )
                            .frame(maxWidth: 420)
                            .padding(.horizontal, 16)
                        }
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
            .sheet(item: $activeDocumentPicker) { pickerKind in
                SystemDocumentPicker(
                    contentTypes: pickerKind.contentTypes,
                    allowsMultipleSelection: false,
                    onPick: { urls in
                        handleTXTImport(.success(urls))
                    },
                    onCancel: {
                        txtTransferStatus = "Импорт TXT отменен пользователем"
                    }
                )
            }
            .sheet(isPresented: $showingTXTShareSheet, onDismiss: {
                txtExportURL = nil
            }) {
                if let txtExportURL {
                    ShareSheet(activityItems: [txtExportURL])
                }
            }
            .onDisappear {
                if settingsChanged {
                    NotificationCenter.default.post(name: .settingsChanged, object: nil)
                }
            }
        }
        .navigationViewStyle(.stack)
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
    
    private func exportLibraryTXT() {
        let stateStore = SatelliteFrequencyStateStore.shared
        var lines: [String] = []

        for noradID in libraryStore.availableNoradIDs.sorted() {
            for item in libraryStore.channels(forNoradID: noradID) {
                let state = stateStore.state(for: noradID, item: item)
                let effective = stateStore.effectiveItem(for: noradID, item: item)
                let rx = formatExportDouble(effective.rxMHz)
                let tx = formatExportDouble(effective.txMHz)
                let width = effective.channelWidthKHz.map(String.init) ?? ""
                let comment = escapeTXTField(state.comment)
                lines.append("\(noradID),\(rx),\(tx),\(width),\(comment);")
            }
        }

        do {
            let text = lines.joined(separator: "\n")
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyyMMdd-HHmmss"
            let filename = "satcom-library-\(formatter.string(from: Date())).txt"
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
            try text.data(using: .utf8)?.write(to: url, options: .atomic)
            txtExportURL = url
            showingTXTShareSheet = true
            txtTransferStatus = "TXT-файл подготовлен: \(filename)"
        } catch {
            txtTransferStatus = "Не удалось подготовить TXT: \(error.localizedDescription)"
        }
    }

    private func handleTXTImport(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let error):
            txtTransferStatus = "Ошибка импорта TXT: \(error.localizedDescription)"
        case .success(let urls):
            guard let url = urls.first else {
                txtTransferStatus = "TXT-файл не выбран"
                return
            }
            importLibraryTXT(from: url)
        }
    }

    private func importLibraryTXT(from url: URL) {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            let data = try Data(contentsOf: url)
            guard let text = String(data: data, encoding: .utf8) else {
                txtTransferStatus = "Неверная кодировка TXT. Используйте UTF-8."
                return
            }

            var byNorad: [Int: [SatelliteFrequencyItem]] = [:]
            var statesBySatellite: [Int: [String: SatelliteFrequencyStateStore.FrequencyState]] = [:]
            var seen = Set<String>()
            var importedRows = 0
            var skippedRows = 0
            var invalidFormatCount = 0
            var invalidNoradCount = 0
            var invalidFrequencyCount = 0
            var invalidWidthCount = 0
            var duplicateCount = 0

            let rawRecords = splitEscapedRecords(text)
            for rawRecord in rawRecords {
                let record = rawRecord.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !record.isEmpty else { continue }
                let fields = splitEscapedCSVLine(record)
                guard fields.count >= 5 else {
                    skippedRows += 1
                    invalidFormatCount += 1
                    continue
                }

                guard let noradID = Int(fields[0].trimmingCharacters(in: .whitespacesAndNewlines)),
                      noradID > 0 else {
                    skippedRows += 1
                    invalidNoradCount += 1
                    continue
                }

                let rx = parseExportDouble(fields[1])
                let tx = parseExportDouble(fields[2])
                if rx == nil && tx == nil {
                    skippedRows += 1
                    invalidFrequencyCount += 1
                    continue
                }

                let rawWidth = fields[3].trimmingCharacters(in: .whitespacesAndNewlines)
                let width: Int?
                if rawWidth.isEmpty {
                    width = nil
                } else if let parsedWidth = Int(rawWidth), parsedWidth > 0 {
                    width = parsedWidth
                } else {
                    skippedRows += 1
                    invalidWidthCount += 1
                    continue
                }

                let rawComment = fields.dropFirst(4).joined(separator: ",")
                let comment = unescapeTXTField(rawComment).trimmingCharacters(in: .whitespacesAndNewlines)

                let spacing: Double?
                if let rx, let tx {
                    spacing = abs(tx - rx)
                } else {
                    spacing = nil
                }

                let item = SatelliteFrequencyItem(
                    rxMHz: rx,
                    txMHz: tx,
                    spacingMHz: spacing,
                    channelWidthKHz: width
                )

                let globalKey = "\(noradID)#\(item.storageKey)"
                if seen.contains(globalKey) {
                    skippedRows += 1
                    duplicateCount += 1
                    continue
                }
                seen.insert(globalKey)

                byNorad[noradID, default: []].append(item)

                if !comment.isEmpty {
                    var state = SatelliteFrequencyStateStore.FrequencyState()
                    state.comment = comment
                    statesBySatellite[noradID, default: [:]][item.storageKey] = state
                }

                importedRows += 1
            }

            guard importedRows > 0 else {
                txtTransferStatus = "Импорт не выполнен: корректные каналы не найдены (пропущено \(skippedRows))."
                libraryStatus = "Проверьте формат строк: norad,rx,tx,width,comment;"
                return
            }

            var reasons: [String] = []
            if invalidFormatCount > 0 { reasons.append("формат: \(invalidFormatCount)") }
            if invalidNoradCount > 0 { reasons.append("norad: \(invalidNoradCount)") }
            if invalidFrequencyCount > 0 { reasons.append("rx/tx: \(invalidFrequencyCount)") }
            if invalidWidthCount > 0 { reasons.append("ширина: \(invalidWidthCount)") }
            if duplicateCount > 0 { reasons.append("дубликаты: \(duplicateCount)") }
            pendingTXTImport = PendingTXTImport(
                byNorad: byNorad,
                statesBySatellite: statesBySatellite,
                importedRows: importedRows,
                skippedRows: skippedRows,
                reasons: reasons,
                satellitesCount: byNorad.keys.count
            )
            txtTransferStatus = "TXT проверен: \(importedRows) каналов, \(byNorad.keys.count) спутников. Выберите режим импорта."
            libraryStatus = "Выберите: дополнить или заменить библиотеку"
        } catch {
            txtTransferStatus = "Не удалось импортировать TXT: \(error.localizedDescription)"
        }
    }

    private func applyParsedTXTImport(_ payload: PendingTXTImport, mode: TXTImportMode) {
        let stateStore = SatelliteFrequencyStateStore.shared

        switch mode {
        case .replace:
            libraryStore.replaceLibrary(byNorad: payload.byNorad)
            stateStore.applyBackupSnapshot(payload.statesBySatellite)
            let importedNoradIDs = payload.byNorad.keys.sorted()
            settings.noradIDs = importedNoradIDs
            settings.customIDs = []
        case .merge:
            let current = buildCurrentLibrarySnapshot()
            var merged = current
            for (noradID, items) in payload.byNorad {
                let existingKeys = Set((merged[noradID] ?? []).map(\.storageKey))
                var combined = merged[noradID] ?? []
                for item in items where !existingKeys.contains(item.storageKey) {
                    combined.append(item)
                }
                merged[noradID] = combined
            }
            libraryStore.replaceLibrary(byNorad: merged)

            var mergedStates = stateStore.makeBackupSnapshot()
            for (satID, incomingStates) in payload.statesBySatellite {
                var satStates = mergedStates[satID] ?? [:]
                for (key, incoming) in incomingStates where satStates[key] == nil {
                    satStates[key] = incoming
                }
                mergedStates[satID] = satStates
            }
            stateStore.applyBackupSnapshot(mergedStates)

            let unionNorad = Set(settings.noradIDs).union(payload.byNorad.keys)
            settings.noradIDs = Array(unionNorad).sorted()
        }

        settingsChanged = true

        if payload.skippedRows > 0, !payload.reasons.isEmpty {
            txtTransferStatus = "Импорт завершен: \(payload.importedRows) каналов, \(payload.satellitesCount) спутников. Пропущено: \(payload.skippedRows) (\(payload.reasons.joined(separator: ", ")))."
        } else {
            txtTransferStatus = "Импорт завершен: \(payload.importedRows) каналов, \(payload.satellitesCount) спутников."
        }

        switch mode {
        case .merge:
            libraryStatus = "TXT импортирован: данные дополнены"
        case .replace:
            libraryStatus = "TXT импортирован: библиотека полностью заменена"
        }
    }

    private func buildCurrentLibrarySnapshot() -> [Int: [SatelliteFrequencyItem]] {
        var snapshot: [Int: [SatelliteFrequencyItem]] = [:]
        for noradID in libraryStore.availableNoradIDs {
            let channels = libraryStore.channels(forNoradID: noradID)
            if !channels.isEmpty {
                snapshot[noradID] = channels
            }
        }
        return snapshot
    }

    private func formatExportDouble(_ value: Double?) -> String {
        guard let value else { return "" }
        return String(format: "%.3f", value)
    }

    private func parseExportDouble(_ raw: String) -> Double? {
        let value = raw
            .replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }
        return Double(value)
    }

    private func escapeTXTField(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: ",", with: "\\,")
            .replacingOccurrences(of: ";", with: "\\;")
            .replacingOccurrences(of: "\n", with: "\\n")
    }

    private func unescapeTXTField(_ value: String) -> String {
        var result = ""
        var escaping = false
        for ch in value {
            if escaping {
                switch ch {
                case "n": result.append("\n")
                case ",": result.append(",")
                case ";": result.append(";")
                case "\\": result.append("\\")
                default:
                    result.append(ch)
                }
                escaping = false
            } else if ch == "\\" {
                escaping = true
            } else {
                result.append(ch)
            }
        }
        if escaping { result.append("\\") }
        return result
    }

    private func splitEscapedCSVLine(_ line: String) -> [String] {
        var fields: [String] = []
        var current = ""
        var escaping = false
        for ch in line {
            if escaping {
                current.append("\\")
                current.append(ch)
                escaping = false
                continue
            }
            if ch == "\\" {
                escaping = true
                continue
            }
            if ch == "," {
                fields.append(current)
                current = ""
            } else {
                current.append(ch)
            }
        }
        if escaping { current.append("\\") }
        fields.append(current)
        return fields
    }

    private func splitEscapedRecords(_ text: String) -> [String] {
        var records: [String] = []
        var current = ""
        var escaping = false

        for ch in text {
            if escaping {
                current.append("\\")
                current.append(ch)
                escaping = false
                continue
            }

            if ch == "\\" {
                escaping = true
                continue
            }

            if ch == ";" {
                let trimmed = current.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    records.append(trimmed)
                }
                current = ""
            } else {
                current.append(ch)
            }
        }

        if escaping { current.append("\\") }

        let tail = current.trimmingCharacters(in: .whitespacesAndNewlines)
        if !tail.isEmpty {
            records.append(tail)
        }
        return records
    }
    
    private func clearAllAppData() {
        settings.clearAllSatellites()
        settings.lastCacheUpdate = Date.distantPast
        libraryStore.clearAllData()
        SatelliteFrequencyStateStore.shared.clearAll()
        libraryStatus = "Все данные приложения удалены"
        githubSyncStatus = nil
        settingsChanged = true
    }

    @MainActor
    private func syncFrequenciesFromGitHub() async {
        isSyncingGitHubFrequencies = true
        defer { isSyncingGitHubFrequencies = false }

        do {
            let versionURL = settings.frequencyVersionURL.trimmingCharacters(in: .whitespacesAndNewlines)
            let summary = try await libraryStore.syncFromGitHub(
                databaseURLString: settings.frequencyDatabaseURL.trimmingCharacters(in: .whitespacesAndNewlines),
                versionURLString: versionURL.isEmpty ? nil : versionURL
            )
            if settings.allActiveIDs.isEmpty {
                settings.noradIDs = libraryStore.availableNoradIDs
                settingsChanged = true
            }
            switch summary.mode {
            case .bootstrap:
                githubSyncStatus = "Базовая библиотека загружена с GitHub: \(summary.rowsCount) строк, \(summary.satellitesCount) спутников."
            case .updated:
                githubSyncStatus = "Библиотека обновлена до версии \(summary.version ?? "unknown"): \(summary.rowsCount) строк, \(summary.satellitesCount) спутников."
            case .upToDate:
                githubSyncStatus = "Доступна актуальная версия. Текущая версия: \(summary.version ?? "unknown")."
            }
        } catch {
            githubSyncStatus = "Ошибка синхронизации с GitHub: \(error.localizedDescription)"
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
                .background(UITheme.surfaceBackground(for: colorScheme))
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
            
        }
        .padding(.vertical, 4)
    }

    private var gpsStatusMessage: (message: String, isError: Bool)? {
        if locationManager.currentLocation != nil {
            return ("GPS работает. Координаты получены.", false)
        }

        if let error = locationManager.locationError, !error.isEmpty {
            return ("Ошибка GPS: \(error). Проверьте сигнал и попробуйте на открытом месте.", true)
        }

        if !locationManager.hasPermission {
            switch locationManager.authorizationStatus {
            case .denied, .restricted:
                return ("GPS отключен для приложения. Включите доступ к геопозиции в настройках телефона.", true)
            case .notDetermined:
                return ("Доступ к GPS еще не выдан. Нажмите «Разрешить доступ».", true)
            default:
                return ("GPS недоступен. Проверьте настройки геолокации.", true)
            }
        }

        return ("Ожидание сигнала GPS. Если координаты не появляются, проверьте геолокацию и интернет.", true)
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
                .background(UITheme.surfaceBackground(for: colorScheme))
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
            
        }
        .padding(.vertical, 4)
    }
}

private struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) { }
}

private struct FrequencyTXTImportModeSheet: View {
    let importedRows: Int
    let satellitesCount: Int
    let onMerge: () -> Void
    let onReplace: () -> Void
    let onCancel: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.14))
                    .frame(width: 64, height: 64)
                Image(systemName: "arrow.triangle.branch")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.blue)
            }

            VStack(spacing: 6) {
                Text("Импорт TXT")
                    .font(.title3.weight(.bold))
                Text("Найдено \(importedRows) каналов, \(satellitesCount) спутников. Выберите, как загрузить данные.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 10) {
                Button(action: onMerge) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Дополнить данные")
                            .font(.headline)
                        Text("Добавит новые каналы, текущие данные останутся.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)

                Button(action: onReplace) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Полностью заменить")
                            .font(.headline)
                        Text("Заменит библиотеку данными из TXT.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.bordered)
                .tint(.red)

                Button("Отмена", action: onCancel)
                    .buttonStyle(.plain)
                    .padding(.top, 4)
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(UITheme.surfaceBackground(for: colorScheme))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(UITheme.cardBorder(for: colorScheme), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.2), radius: 20, y: 10)
    }
}

private struct SystemDocumentPicker: UIViewControllerRepresentable {
    let contentTypes: [UTType]
    let allowsMultipleSelection: Bool
    let onPick: ([URL]) -> Void
    let onCancel: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick, onCancel: onCancel)
    }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let controller = UIDocumentPickerViewController(
            forOpeningContentTypes: contentTypes,
            asCopy: true
        )
        controller.delegate = context.coordinator
        controller.allowsMultipleSelection = allowsMultipleSelection
        return controller
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) { }

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        private let onPick: ([URL]) -> Void
        private let onCancel: () -> Void

        init(onPick: @escaping ([URL]) -> Void, onCancel: @escaping () -> Void) {
            self.onPick = onPick
            self.onCancel = onCancel
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            onPick(urls)
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            onCancel()
        }
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
                    Text("Удалить все данные?")
                        .font(.title3)
                        .fontWeight(.bold)
                    
                    Text("Это действие полностью очистит приложение. Восстановить данные после удаления будет нельзя.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Label("Удалится весь список спутников", systemImage: "satellite")
                    Label("Удалится библиотека частот и загруженный кэш", systemImage: "trash")
                    Label("Удалятся пользовательские частоты, заметки и статусы", systemImage: "person.crop.circle.badge.xmark")
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
                        
                        Text("Свайп вправо для удаления")
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

private struct FrequencyLibrarySyncConfirmSheet: View {
    let onConfirm: () -> Void
    let onCancel: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.14))
                    .frame(width: 64, height: 64)
                Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.blue)
            }

            VStack(spacing: 8) {
                Text("Обновить библиотеку с GitHub?")
                    .font(.title3.weight(.bold))
                Text("Текущая библиотека частот будет полностью заменена новыми данными.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                Text("Перед обновлением рекомендуется сделать резервную копию через «Скачать библиотеку (TXT)».")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 10) {
                Button("Отмена", action: onCancel)
                    .buttonStyle(.bordered)
                Button("Обновить", action: onConfirm)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(UITheme.surfaceBackground(for: colorScheme))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(UITheme.cardBorder(for: colorScheme), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.2), radius: 20, y: 10)
    }
}
