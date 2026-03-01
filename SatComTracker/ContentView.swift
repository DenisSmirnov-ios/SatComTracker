import SwiftUI
import CoreLocation
import Combine
import MapKit

// UI Компоненты

struct ActiveCompassView: View {
    let satelliteAzimuth: Double
    @ObservedObject var compassManager: CompassManager
    
    var relativeAzimuth: Double {
        let diff = satelliteAzimuth - compassManager.heading
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
                .rotationEffect(.degrees(-compassManager.heading))
            
            Text("S")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.blue)
                .offset(y: 90)
                .rotationEffect(.degrees(-compassManager.heading))
            
            Text("W")
                .font(.system(size: 20, weight: .bold))
                .offset(x: -90)
                .rotationEffect(.degrees(-compassManager.heading))
            
            Text("E")
                .font(.system(size: 20, weight: .bold))
                .offset(x: 90)
                .rotationEffect(.degrees(-compassManager.heading))
            
            Triangle()
                .fill(Color.red)
                .frame(width: 24, height: 36)
                .offset(y: -85)
                .rotationEffect(.degrees(relativeAzimuth))
            
            Circle()
                .fill(Color.blue.opacity(0.3))
                .frame(width: 20, height: 20)
            
            if compassManager.isCalibrating {
                Text("⚠️")
                    .font(.caption)
                    .offset(y: 70)
            }
        }
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

// SatelliteRow
struct SatelliteRow: View {
    let satellite: Satellite
    @ObservedObject var frequencyStore = FrequencyStore.shared
    
    var body: some View {
        HStack {
            Image(systemName: satellite.isVisible ? "eye.fill" : "eye.slash.fill")
                .foregroundColor(satellite.isVisible ? .green : .red)
                .font(.caption)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(satellite.name)
                    .font(.headline)
                    .foregroundColor(satellite.isVisible ? .primary : .red)
                    .lineLimit(1)
                
                HStack(spacing: 4) {
                    Text("ID: \(satellite.id)")
                        .font(.caption2)
                        .foregroundColor(.gray)
                    
                    if !satellite.isVisible {
                        Text("↓ ГОРИЗОНТА")
                            .font(.caption2)
                            .foregroundColor(.red)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(2)
                    }
                    
                    // Показываем количество предустановленных частот
                    let channels = frequencyStore.getPredefinedChannels(for: satellite.id)
                    if !channels.isEmpty {
                        Text("📡 \(channels.count)")
                            .font(.caption2)
                            .foregroundColor(.blue)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(2)
                    }
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "%.1f°", satellite.elevation))
                    .font(.system(.body, design: .monospaced))
                    .fontWeight(.bold)
                    .foregroundColor(satellite.isVisible ? .green : .red)
                
                if satellite.isError {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

// Экран редактирования каналов связи

struct FrequencyEditView: View {
    let satelliteId: Int
    let satelliteName: String
    @ObservedObject var frequencyStore = FrequencyStore.shared
    @Environment(\.dismiss) var dismiss
    @State private var showingPredefinedAlert = false
    
    @State private var channels: [FrequencyStore.CommunicationChannel] = []
    @State private var showingAddChannel = false
    @State private var editingChannel: FrequencyStore.CommunicationChannel?
    @State private var editingPredefinedChannel: FrequencyStore.CommunicationChannel?
    
    var body: some View {
        NavigationView {
            List {
                // Секция с предустановленными частотами
                if !predefinedChannels.isEmpty {
                    Section(header: Text("📡 Предустановленные каналы (\(predefinedChannels.count))")) {
                        ForEach(predefinedChannels) { channel in
                            PredefinedChannelRow(channel: channel)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    editingPredefinedChannel = channel
                                }
                        }
                        
                        if predefinedChannels.count > 5 {
                            Button("Показать все \(predefinedChannels.count) каналов") {
                                showingPredefinedAlert = true
                            }
                            .font(.caption)
                            .foregroundColor(.blue)
                        }
                    }
                }
                
                // Секция с пользовательскими каналами
                Section(header: Text("📝 Пользовательские каналы (\(channels.count))")) {
                    if channels.isEmpty {
                        Text("Нет пользовательских каналов")
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
                            Text("Добавить свой канал")
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
            .sheet(item: $editingPredefinedChannel) { channel in
                PredefinedChannelEditView(
                    satelliteName: satelliteName,
                    channel: channel,
                    frequencyStore: frequencyStore,
                    onSave: {
                        // Обновляем отображение
                    }
                )
            }
            .alert("Предустановленные каналы", isPresented: $showingPredefinedAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                let channelList = predefinedChannels.map {
                    "• \($0.name): RX \($0.rxFrequency), TX \($0.txFrequency)"
                }.joined(separator: "\n")
                Text(channelList)
            }
            .onAppear {
                channels = frequencyStore.getFrequencies(for: satelliteId).channels
            }
        }
    }
    
    // используем satelliteId для получения предустановленных каналов
    private var predefinedChannels: [FrequencyStore.CommunicationChannel] {
        frequencyStore.getPredefinedChannels(for: satelliteId)
    }
}

// редактирование предустановленного канала
struct PredefinedChannelEditView: View {
    let satelliteName: String
    let channel: FrequencyStore.CommunicationChannel
    let frequencyStore: FrequencyStore
    let onSave: () -> Void
    
    @Environment(\.dismiss) var dismiss
    @State private var name: String
    @State private var rxFrequency: String
    @State private var txFrequency: String
    @State private var showResetButton: Bool
    
    init(satelliteName: String, channel: FrequencyStore.CommunicationChannel, frequencyStore: FrequencyStore, onSave: @escaping () -> Void) {
        self.satelliteName = satelliteName
        self.channel = channel
        self.frequencyStore = frequencyStore
        self.onSave = onSave
        
        // Извлекаем числовые значения из строк
        let rxValue = channel.rxFrequency.replacingOccurrences(of: " MHz", with: "")
        let txValue = channel.txFrequency.replacingOccurrences(of: " MHz", with: "")
        
        _name = State(initialValue: channel.name)
        _rxFrequency = State(initialValue: rxValue)
        _txFrequency = State(initialValue: txValue)
        _showResetButton = State(initialValue: channel.isPredefined && channel.originalData != nil)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("📝 Название канала")) {
                    TextField("Название", text: $name)
                }
                
                Section(header: Text("📡 Частоты")) {
                    HStack {
                        Text("RX:")
                            .foregroundColor(.green)
                        TextField("Частота RX", text: $rxFrequency)
                            .keyboardType(.decimalPad)
                    }
                    
                    HStack {
                        Text("TX:")
                            .foregroundColor(.orange)
                        TextField("Частота TX", text: $txFrequency)
                            .keyboardType(.decimalPad)
                    }
                }
                
                Section {
                    Button("💾 Сохранить изменения") {
                        saveChanges()
                    }
                    .frame(maxWidth: .infinity)
                    
                    if showResetButton {
                        Button("↺ Сбросить к оригиналу", role: .destructive) {
                            resetToOriginal()
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .navigationTitle("Редактировать канал")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Отмена") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func saveChanges() {
        guard let rxDouble = Double(rxFrequency),
              let txDouble = Double(txFrequency) else { return }
        
        frequencyStore.updatePredefinedFrequency(
            satelliteName: satelliteName,
            frequencyId: channel.id,
            newRX: rxDouble,
            newTX: txDouble,
            newName: name
        )
        
        onSave()
        dismiss()
    }
    
    private func resetToOriginal() {
        frequencyStore.resetPredefinedFrequency(
            satelliteName: satelliteName,
            frequencyId: channel.id
        )
        onSave()
        dismiss()
    }
}

struct PredefinedChannelRow: View {
    let channel: FrequencyStore.CommunicationChannel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(channel.name)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
                
                if channel.originalData != nil {
                    Image(systemName: "pencil.circle.fill")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
            }
            
            HStack {
                Label(channel.rxFrequency, systemImage: "arrow.down.circle")
                    .font(.caption2)
                    .foregroundColor(.green)
                Label(channel.txFrequency, systemImage: "arrow.up.circle")
                    .font(.caption2)
                    .foregroundColor(.orange)
            }
            
            if !channel.notes.isEmpty {
                Text(channel.notes)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
    }
}

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
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("TX")
                        .font(.caption2)
                        .foregroundColor(.orange)
                    Text(channel.txFrequency.isEmpty ? "—" : channel.txFrequency)
                        .font(.system(.caption, design: .monospaced))
                }
            }
            
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
            
            // Извлекаем числовые значения из строк
            let rxValue = channel.rxFrequency.replacingOccurrences(of: " MHz", with: "")
            let txValue = channel.txFrequency.replacingOccurrences(of: " MHz", with: "")
            
            _rxFrequency = State(initialValue: rxValue)
            _txFrequency = State(initialValue: txValue)
            _notes = State(initialValue: channel.notes)
        }
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("📝 Название канала")) {
                    TextField("Например: Основной", text: $name)
                }
                
                Section(header: Text("📡 Частоты")) {
                    HStack {
                        Text("RX:")
                            .foregroundColor(.green)
                        TextField("243.625", text: $rxFrequency)
                            .keyboardType(.decimalPad)
                    }
                    
                    HStack {
                        Text("TX:")
                            .foregroundColor(.orange)
                        TextField("316.725", text: $txFrequency)
                            .keyboardType(.decimalPad)
                    }
                }
                
                Section(header: Text("📝 Заметки")) {
                    TextEditor(text: $notes)
                        .frame(minHeight: 80)
                }
                
                Section {
                    Button(channel == nil ? "💾 Добавить" : "💾 Сохранить") {
                        saveChannel()
                    }
                    .frame(maxWidth: .infinity)
                    
                    if channel != nil {
                        Button("🗑 Удалить", role: .destructive) {
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
            .navigationTitle(channel == nil ? "Новый канал" : "Редактировать")
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
        let rxWithUnit = rxFrequency.isEmpty ? "" : "\(rxFrequency) MHz"
        let txWithUnit = txFrequency.isEmpty ? "" : "\(txFrequency) MHz"
        
        if let existingChannel = channel {
            var updatedChannel = existingChannel
            updatedChannel.name = name
            updatedChannel.rxFrequency = rxWithUnit
            updatedChannel.txFrequency = txWithUnit
            updatedChannel.notes = notes
            frequencyStore.updateChannel(for: satelliteId, channel: updatedChannel)
        } else {
            let newChannel = FrequencyStore.CommunicationChannel(
                name: name,
                rxFrequency: rxWithUnit,
                txFrequency: txWithUnit,
                notes: notes
            )
            frequencyStore.addChannel(for: satelliteId, channel: newChannel)
        }
        onSave()
        dismiss()
    }
}

// Карточка спутника

struct SatelliteDetailView: View {
    let satellite: Satellite
    @ObservedObject var compassManager: CompassManager
    @ObservedObject var frequencyStore = FrequencyStore.shared
    @State private var showFrequencyEdit = false
    
    private let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .medium
        f.dateStyle = .none
        return f
    }()
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                HeaderView(satellite: satellite)
                UpdateTimeView(timestamp: satellite.timestamp, timeFormatter: timeFormatter)
                
                if !satellite.isVisible {
                    BelowHorizonWarning(elevation: satellite.elevation)
                }
                
                if satellite.isVisible {
                    CompassSection(satellite: satellite, compassManager: compassManager)
                }
                
                // передаем satellite.id и satellite.name
                FrequencySection(satelliteId: satellite.id, satelliteName: satellite.name, onEdit: { showFrequencyEdit = true })
            }
            .padding()
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showFrequencyEdit = true }) {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 16))
                        .overlay(
                            Group {
                                let channels = frequencyStore.getPredefinedChannels(for: satellite.id)
                                if !channels.isEmpty {
                                    Text("\(channels.count)")
                                        .font(.system(size: 8))
                                        .foregroundColor(.white)
                                        .padding(4)
                                        .background(Color.red)
                                        .clipShape(Circle())
                                        .offset(x: 10, y: -10)
                                }
                            }
                        )
                }
            }
        }
        .sheet(isPresented: $showFrequencyEdit) {
            FrequencyEditView(satelliteId: satellite.id, satelliteName: satellite.name)
        }
        .onAppear {
            compassManager.start()
        }
        .onDisappear {
            compassManager.stop()
        }
    }
}

struct HeaderView: View {
    let satellite: Satellite
    
    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: satellite.isVisible ? "circle.fill" : "circle")
                    .font(.system(size: 10))
                    .foregroundColor(satellite.isVisible ? .green : .red)
                
                Text(satellite.name)
                    .font(.title2)
                    .fontWeight(.bold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            
            Text("NORAD: \(satellite.id)")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
        }
        .padding(.top, 8)
    }
}

struct UpdateTimeView: View {
    let timestamp: Date
    let timeFormatter: DateFormatter
    
    var body: some View {
        HStack {
            Spacer()
            Label(timeFormatter.string(from: timestamp), systemImage: "clock.arrow.circlepath")
                .font(.caption2)
                .foregroundColor(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
        }
    }
}

struct BelowHorizonWarning: View {
    let elevation: Double
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "eye.slash.fill")
                    .foregroundColor(.red)
                Text("Спутник ниже горизонта")
                    .font(.headline)
                    .foregroundColor(.red)
            }
            
            Text(String(format: "Элевация: %.1f° ниже горизонта", abs(elevation)))
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.red.opacity(0.1))
        .cornerRadius(16)
    }
}

struct CompassSection: View {
    let satellite: Satellite
    @ObservedObject var compassManager: CompassManager
    
    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Label("Наведение на спутник", systemImage: "scope")
                    .font(.headline)
                Spacer()
                if compassManager.isCalibrating {
                    Label("Калибровка", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
            
            ActiveCompassView(satelliteAzimuth: satellite.azimuth, compassManager: compassManager)
                .frame(height: 220)
            
            HStack(spacing: 30) {
                VStack(spacing: 4) {
                    Text("АЗИМУТ")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(String(format: "%.0f°", satellite.azimuth))
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(.blue)
                }
                
                Divider()
                    .frame(height: 40)
                
                VStack(spacing: 4) {
                    Text("ЭЛЕВАЦИЯ")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(String(format: "%.0f°", satellite.elevation))
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(.green)
                }
            }
            .padding(.vertical, 8)
            
            VStack(alignment: .leading, spacing: 10) {
                InstructionRow(number: 1, text: "Встаньте лицом на север")
                InstructionRow(number: 2, text: String(format: "Повернитесь на %.0f° вправо", satellite.azimuth))
                InstructionRow(number: 3, text: String(format: "Поднимите взгляд на %.0f°", satellite.elevation))
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.blue.opacity(0.05))
            .cornerRadius(12)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
    }
}

struct InstructionRow: View {
    let number: Int
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Text("\(number)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 20, height: 20)
                .background(Circle().fill(Color.blue))
            
            Text(text)
                .font(.subheadline)
            
            Spacer()
        }
    }
}

// FrequencySection
struct FrequencySection: View {
    let satelliteId: Int
    let satelliteName: String
    let onEdit: () -> Void
    @ObservedObject var frequencyStore = FrequencyStore.shared
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Label("Каналы связи", systemImage: "antenna.radiowaves.left.and.right")
                    .font(.headline)
                Spacer()
                Button(action: onEdit) {
                    Image(systemName: "pencil.circle.fill")
                        .font(.title3)
                        .foregroundColor(.blue)
                }
            }
            
            let userFreqs = frequencyStore.getFrequencies(for: satelliteId).channels
            let predefinedFreqs = frequencyStore.getPredefinedChannels(for: satelliteId)
            
            if userFreqs.isEmpty && predefinedFreqs.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "wave.3.right.circle")
                        .font(.system(size: 40))
                        .foregroundColor(.gray.opacity(0.5))
                    
                    Text("Нет сохраненных частот")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Button("Добавить канал") {
                        onEdit()
                    }
                    .font(.caption)
                    .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
                .background(Color.gray.opacity(0.05))
                .cornerRadius(16)
            } else {
                VStack(spacing: 10) {
                    // Показываем предустановленные частоты
                    if !predefinedFreqs.isEmpty {
                        ForEach(predefinedFreqs.prefix(3)) { channel in
                            CompactChannelCard(channel: channel, isPredefined: true)
                        }
                        
                        if predefinedFreqs.count > 3 {
                            Button("Еще \(predefinedFreqs.count - 3) каналов...") {
                                onEdit()
                            }
                            .font(.caption)
                            .foregroundColor(.blue)
                        }
                    }
                    
                    // Показываем пользовательские частоты
                    ForEach(userFreqs) { channel in
                        CompactChannelCard(channel: channel, isPredefined: false)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
    }
}

struct CompactChannelCard: View {
    let channel: FrequencyStore.CommunicationChannel
    let isPredefined: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(channel.name.isEmpty ? "Канал" : channel.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                if isPredefined {
                    if channel.originalData != nil {
                        Image(systemName: "pencil.circle.fill")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    } else {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundColor(.yellow)
                    }
                }
            }
            
            HStack(spacing: 20) {
                Label(title: { Text(channel.rxFrequency.isEmpty ? "—" : channel.rxFrequency) },
                      icon: { Image(systemName: "arrow.down.circle.fill").foregroundColor(.green) })
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(6)
                
                Label(title: { Text(channel.txFrequency.isEmpty ? "—" : channel.txFrequency) },
                      icon: { Image(systemName: "arrow.up.circle.fill").foregroundColor(.orange) })
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(6)
                
                Spacer()
            }
        }
        .padding()
        .background(isPredefined ? Color.blue.opacity(0.05) : Color.gray.opacity(0.05))
        .cornerRadius(12)
    }
}

// Окно карты

struct MapLocationView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var settings: AppSettings
    @StateObject private var geocoderManager = GeocoderManager()
    
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 55.7558, longitude: 37.6173),
        span: MKCoordinateSpan(latitudeDelta: 10, longitudeDelta: 10)
    )
    @State private var selectedCoordinate: CLLocationCoordinate2D?
    @State private var searchText = ""
    @State private var isSearching = false
    @State private var selectedAddress: String?
    @State private var mapType: MKMapType = .standard
    @State private var showMapTypePicker = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Поиск
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    TextField("Поиск города или места", text: $searchText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.words)
                    
                    if isSearching {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }
                .padding()
                
                // Результаты поиска
                if !geocoderManager.searchResults.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(geocoderManager.searchResults) { result in
                                Button(action: {
                                    selectLocation(result.coordinate, title: result.title)
                                }) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(result.title)
                                            .font(.caption)
                                            .fontWeight(.medium)
                                            .lineLimit(1)
                                        Text(result.subtitle)
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(8)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.bottom, 8)
                }
                
                // Карта
                ZStack {
                    MapView(region: $region, selectedCoordinate: $selectedCoordinate, mapType: mapType)
                        .edgesIgnoringSafeArea(.bottom)
                    
                    VStack {
                        HStack {
                            Spacer()
                            
                            // Кнопка выбора типа карты
                            Menu {
                                Button("Схема") { mapType = .standard }
                                Button("Спутник") { mapType = .satellite }
                                Button("Гибрид") { mapType = .hybrid }
                            } label: {
                                Image(systemName: "map")
                                    .padding(10)
                                    .background(Color.white)
                                    .clipShape(Circle())
                                    .shadow(radius: 3)
                            }
                            .padding()
                        }
                        
                        Spacer()
                        
                        // Информация о выбранной точке
                        if let coordinate = selectedCoordinate {
                            VStack(spacing: 8) {
                                if let address = selectedAddress {
                                    Text(address)
                                        .font(.caption)
                                        .multilineTextAlignment(.center)
                                }
                                
                                Text(String(format: "Ш: %.4f°, Д: %.4f°", coordinate.latitude, coordinate.longitude))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                
                                HStack(spacing: 16) {
                                    Button("Выбрать") {
                                        settings.manualLatitude = String(format: "%.6f", coordinate.latitude)
                                        settings.manualLongitude = String(format: "%.6f", coordinate.longitude)
                                        settings.locationSource = .map
                                        dismiss()
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .controlSize(.small)
                                    
                                    Button("Отмена") {
                                        selectedCoordinate = nil
                                        selectedAddress = nil
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                }
                            }
                            .padding()
                            .background(Color(.systemBackground).opacity(0.95))
                            .cornerRadius(12)
                            .shadow(radius: 5)
                            .padding()
                        }
                    }
                }
            }
            .navigationTitle("Выбор на карте")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Отмена") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Моё местоположение") {
                        if let location = LocationManager().currentLocation {
                            region.center = location.coordinate
                            region.span = MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
                        }
                    }
                }
            }
            .onChange(of: searchText) { newValue in
                geocoderManager.searchAddress(newValue)
            }
            .onChange(of: selectedCoordinate.map { "\($0.latitude),\($0.longitude)" }) { newValue in
                guard let coordinate = selectedCoordinate else { return }
                geocoderManager.getAddressFromCoordinates(
                    latitude: coordinate.latitude,
                    longitude: coordinate.longitude
                ) { address in
                    selectedAddress = address
                }
            }
            .onAppear {
                if let lat = Double(settings.manualLatitude),
                   let lon = Double(settings.manualLongitude) {
                    region.center = CLLocationCoordinate2D(latitude: lat, longitude: lon)
                }
            }
        }
    }
    
    private func selectLocation(_ coordinate: CLLocationCoordinate2D, title: String) {
        selectedCoordinate = coordinate
        region.center = coordinate
        region.span = MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
        searchText = title
        geocoderManager.searchResults = []
    }
}

// UIViewRepresentable для MKMapView

struct MapView: UIViewRepresentable {
    @Binding var region: MKCoordinateRegion
    @Binding var selectedCoordinate: CLLocationCoordinate2D?
    var mapType: MKMapType
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.mapType = mapType
        mapView.showsUserLocation = true
        mapView.showsCompass = true
        mapView.showsScale = true
        
        let longPressGesture = UILongPressGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleLongPress(_:))
        )
        mapView.addGestureRecognizer(longPressGesture)
        
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        mapView.mapType = mapType
        mapView.setRegion(region, animated: true)
        
        // Обновление аннотаций
        mapView.removeAnnotations(mapView.annotations)
        
        if let coordinate = selectedCoordinate {
            let annotation = MKPointAnnotation()
            annotation.coordinate = coordinate
            annotation.title = "Выбранная точка"
            mapView.addAnnotation(annotation)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: MapView
        
        init(_ parent: MapView) {
            self.parent = parent
        }
        
        @objc func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
            if gesture.state == .began {
                let mapView = gesture.view as! MKMapView
                let point = gesture.location(in: mapView)
                let coordinate = mapView.convert(point, toCoordinateFrom: mapView)
                
                parent.selectedCoordinate = coordinate
            }
        }
        
        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            parent.region = mapView.region
        }
        
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if annotation is MKUserLocation {
                return nil
            }
            
            let identifier = "Pin"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKPinAnnotationView
            
            if annotationView == nil {
                annotationView = MKPinAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                annotationView?.canShowCallout = true
                annotationView?.pinTintColor = .red
            } else {
                annotationView?.annotation = annotation
            }
            
            return annotationView
        }
    }
}

// Экран Настроек

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var settings: AppSettings
    @ObservedObject var locationManager: LocationManager
    
    @State private var searchText = ""
    @State private var newCustomID = ""
    @State private var showingClearAlert = false
    @State private var showingMapView = false
    
    // Флаг для отслеживания, были ли изменены настройки
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
                
                // ОБНОВЛЕННАЯ секция местоположения
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
                MapLocationView(settings: settings)
            }
            .onDisappear {
                // Если настройки были изменены, обновляем данные
                if settingsChanged {
                    NotificationCenter.default.post(name: .settingsChanged, object: nil)
                }
            }
        }
    }
    
    // Location Views
    
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

// Главный Экран

extension Notification.Name {
    static let settingsChanged = Notification.Name("settingsChanged")
}

struct ContentView: View {
    @StateObject private var locationManager = LocationManager()
    @StateObject private var apiService = SatelliteAPI()
    @StateObject private var settings = AppSettings()
    @StateObject private var compassManager = CompassManager()
    
    @State private var selectedSatellite: Satellite?
    @State private var showSettings = false
    @State private var refreshTask: Task<Void, Never>?
    @State private var shouldRefreshOnAppear = true
    
    var visibleCount: Int {
        apiService.satellites.filter { $0.isVisible }.count
    }
    
    var body: some View {
        NavigationView {
            Group {
                if !settings.isConfigured {
                    WelcomeView(showSettings: $showSettings)
                } else if settings.locationSource == .gps && !locationManager.hasPermission {
                    LocationPermissionView(locationManager: locationManager, showSettings: $showSettings)
                } else {
                    MainContentView(
                        apiService: apiService,
                        settings: settings,
                        visibleCount: visibleCount,
                        selectedSatellite: $selectedSatellite,
                        onRefresh: refreshData
                    )
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
                    RefreshButton(isLoading: apiService.isLoading, action: refreshData)
                }
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
            startServices()
            
            // Обновляем данные только при первом появлении
            if shouldRefreshOnAppear {
                checkAndRefreshData()
                shouldRefreshOnAppear = false
            }
        }
        .onDisappear {
            refreshTask?.cancel()
            compassManager.stop()
        }
        .onChange(of: settings.isConfigured) { _ in
            if settings.isConfigured {
                refreshData()
            }
        }
        .onChange(of: locationManager.currentLocation) { _ in
            if settings.locationSource == .gps && settings.shouldRefreshCache() {
                refreshData()
            }
        }
        .onChange(of: settings.manualLatitude) { _ in
            if (settings.locationSource == .manual || settings.locationSource == .map) && settings.shouldRefreshCache() {
                refreshData()
            }
        }
        .onChange(of: settings.manualLongitude) { _ in
            if (settings.locationSource == .manual || settings.locationSource == .map) && settings.shouldRefreshCache() {
                refreshData()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .settingsChanged)) { _ in
            // Обновляем данные только если настройки действительно изменились
            refreshData()
        }
    }
    
    private func startServices() {
        if settings.locationSource == .gps {
            locationManager.requestLocation()
        }
        compassManager.start()
    }
    
    private func checkAndRefreshData() {
        Task { @MainActor in
            let coords = await getCoordinates()
            guard let coords = coords else { return }
            
            if settings.shouldRefreshCache() {
                await apiService.fetchSatellites(
                    apiKey: settings.apiKey,
                    noradIDs: settings.allActiveIDs,
                    latitude: coords.latitude,
                    longitude: coords.longitude,
                    altitude: coords.altitude,
                    refreshInterval: settings.refreshInterval,
                    forceRefresh: true,
                    onCacheUpdated: { settings.updateCacheTime() }
                )
            } else if settings.lastCacheUpdate != Date.distantPast {
                // Загружаем из кеша
                await apiService.fetchSatellites(
                    apiKey: settings.apiKey,
                    noradIDs: settings.allActiveIDs,
                    latitude: coords.latitude,
                    longitude: coords.longitude,
                    altitude: coords.altitude,
                    refreshInterval: settings.refreshInterval,
                    forceRefresh: false,
                    onCacheUpdated: nil
                )
            }
        }
    }
    
    private func refreshData() {
        refreshTask?.cancel()
        refreshTask = Task { @MainActor in
            let coords = await getCoordinates()
            guard let coords = coords else { return }
            
            await apiService.fetchSatellites(
                apiKey: settings.apiKey,
                noradIDs: settings.allActiveIDs,
                latitude: coords.latitude,
                longitude: coords.longitude,
                altitude: coords.altitude,
                refreshInterval: settings.refreshInterval,
                forceRefresh: true,
                onCacheUpdated: { settings.updateCacheTime() }
            )
        }
    }
    
    private func getCoordinates() async -> (latitude: Double, longitude: Double, altitude: Double)? {
        switch settings.locationSource {
        case .gps:
            return locationManager.getCurrentCoordinates()
        case .manual, .map:
            return settings.getCurrentCoordinates()
        }
    }
}

// Вспомогательные компоненты главного экрана

struct WelcomeView: View {
    @Binding var showSettings: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("Требуется настройка")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Добавьте API ключ и выберите спутники")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("Перейти в настройки") {
                showSettings = true
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct LocationPermissionView: View {
    @ObservedObject var locationManager: LocationManager
    @Binding var showSettings: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "location.slash")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("Нужен доступ к геопозиции")
                .font(.headline)
            
            Text("Для использования GPS необходимо разрешение")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            HStack(spacing: 16) {
                Button("Разрешить GPS") {
                    locationManager.requestLocation()
                }
                .buttonStyle(.borderedProminent)
                
                Button("Выбрать источник") {
                    showSettings = true
                }
                .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct RefreshButton: View {
    let isLoading: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: "arrow.clockwise")
                .rotationEffect(.degrees(isLoading ? 360 : 0))
                .animation(isLoading ? Animation.linear(duration: 1).repeatForever(autoreverses: false) : .default, value: isLoading)
        }
        .disabled(isLoading)
    }
}

struct MainContentView: View {
    @ObservedObject var apiService: SatelliteAPI
    @ObservedObject var settings: AppSettings
    let visibleCount: Int
    @Binding var selectedSatellite: Satellite?
    let onRefresh: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            if let lastUpdate = apiService.lastUpdateTime {
                InfoBar(lastUpdate: lastUpdate, refreshInterval: settings.refreshIntervalText)
            }
            
            if !apiService.satellites.isEmpty {
                VisibilityIndicator(visible: visibleCount, hidden: apiService.satellites.count - visibleCount)
            }
            
            if apiService.isLoading && apiService.satellites.isEmpty {
                ProgressView("Загрузка данных...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                SatelliteList(
                    satellites: apiService.satellites,
                    errorMessage: apiService.errorMessage,
                    selectedSatellite: $selectedSatellite,
                    onRetry: onRefresh
                )
            }
        }
    }
}

struct InfoBar: View {
    let lastUpdate: Date
    let refreshInterval: String
    
    private let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .medium
        return f
    }()
    
    var body: some View {
        HStack {
            Label(timeFormatter.string(from: lastUpdate), systemImage: "clock")
            Spacer()
            Text(refreshInterval)
        }
        .font(.caption)
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.gray.opacity(0.1))
    }
}

struct VisibilityIndicator: View {
    let visible: Int
    let hidden: Int
    
    var body: some View {
        HStack(spacing: 16) {
            Label("\(visible)", systemImage: "eye.fill")
                .foregroundColor(.green)
            Label("\(hidden)", systemImage: "eye.slash.fill")
                .foregroundColor(.red)
        }
        .font(.caption)
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.gray.opacity(0.1))
    }
}

struct SatelliteList: View {
    let satellites: [Satellite]
    let errorMessage: String?
    @Binding var selectedSatellite: Satellite?
    let onRetry: () -> Void
    
    var body: some View {
        List {
            if let error = errorMessage {
                ErrorRow(message: error, onRetry: onRetry)
            }
            
            ForEach(satellites) { satellite in
                Button(action: { selectedSatellite = satellite }) {
                    SatelliteRow(satellite: satellite)
                }
                .buttonStyle(.plain)
            }
        }
        .listStyle(.plain)
        .refreshable {
            onRetry()
        }
    }
}

struct ErrorRow: View {
    let message: String
    let onRetry: () -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text("Ошибка")
                    .fontWeight(.bold)
            }
            Text(message)
                .font(.caption)
                .foregroundColor(.secondary)
            Button("Повторить", action: onRetry)
                .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .listRowBackground(Color.clear)
    }
}

// Preview
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
