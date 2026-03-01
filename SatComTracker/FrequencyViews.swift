import SwiftUI

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
                ChannelEditView(satelliteId: satelliteId, channel: nil) {
                    channels = frequencyStore.getFrequencies(for: satelliteId).channels
                }
            }
            .sheet(item: $editingChannel) { channel in
                ChannelEditView(satelliteId: satelliteId, channel: channel) {
                    channels = frequencyStore.getFrequencies(for: satelliteId).channels
                }
            }
            .sheet(item: $editingPredefinedChannel) { channel in
                PredefinedChannelEditView(
                    satelliteName: satelliteName,
                    channel: channel,
                    frequencyStore: frequencyStore,
                    onSave: {}
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
    
    private var predefinedChannels: [FrequencyStore.CommunicationChannel] {
        frequencyStore.getPredefinedChannels(for: satelliteId)
    }
}

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
