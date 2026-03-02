import SwiftUI

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

struct SatelliteDetailView: View {
    let satellite: Satellite
    @ObservedObject var compassManager: CompassManager
    @ObservedObject private var libraryStore = SatelliteFrequencyLibraryStore.shared
    
    private var libraryChannels: [SatelliteFrequencyItem] {
        libraryStore.channels(for: satellite)
    }
    
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
                
                LibraryFrequenciesSection(satelliteId: satellite.id, channels: libraryChannels)
            }
            .padding()
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            compassManager.start()
        }
        .onDisappear {
            compassManager.stop()
        }
    }
}

struct LibraryFrequenciesSection: View {
    let satelliteId: Int
    let channels: [SatelliteFrequencyItem]
    @ObservedObject private var stateStore = SatelliteFrequencyStateStore.shared
    private let libraryStore = SatelliteFrequencyLibraryStore.shared
    
    @State private var editingItem: SatelliteFrequencyItem?
    @State private var showOnlyWorking = false
    @State private var showingAddEditor = false
    
    private var visibleChannels: [SatelliteFrequencyItem] {
        channels.filter { item in
            let state = stateStore.state(for: satelliteId, item: item)
            if state.isDeleted { return false }
            if showOnlyWorking && state.isNotWorking { return false }
            return true
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("RX/TX Частоты", systemImage: "dot.radiowaves.left.and.right")
                    .font(.headline)
                Spacer()
                Button {
                    showingAddEditor = true
                } label: {
                    Label("Добавить", systemImage: "plus.circle")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                
                Text("\(visibleChannels.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Toggle("Только рабочие каналы", isOn: $showOnlyWorking)
                .font(.caption)
            
            if visibleChannels.isEmpty {
                Text("Нет активных частот в списке")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                ForEach(visibleChannels) { item in
                    let state = stateStore.state(for: satelliteId, item: item)
                    let effectiveItem = stateStore.effectiveItem(for: satelliteId, item: item)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 10) {
                            Text("RX \(format(effectiveItem.rxMHz))")
                                .font(.caption)
                                .foregroundColor(.green)
                            Text("TX \(format(effectiveItem.txMHz))")
                                .font(.caption)
                                .foregroundColor(.orange)
                            Spacer()
                            
                            if state.isNotWorking {
                                Text("НЕ РАБОТАЕТ")
                                    .font(.caption2)
                                    .foregroundColor(.red)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.red.opacity(0.12))
                                    .cornerRadius(6)
                            }
                            
                            Menu {
                                Button("Редактировать канал") {
                                    editingItem = item
                                }
                                
                                Button("Комментарий") {
                                    editingItem = item
                                }
                                
                                Button(state.isNotWorking ? "Снять пометку \"не работает\"" : "Пометить как \"не работает\"") {
                                    stateStore.setNotWorking(!state.isNotWorking, for: satelliteId, item: item)
                                }
                                
                                Button("Удалить канал навсегда", role: .destructive) {
                                    stateStore.setDeleted(true, for: satelliteId, item: item)
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        HStack(spacing: 10) {
                            Text("Разнос: \(format(effectiveItem.spacingMHz))")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text("Ширина: \(formatWidth(effectiveItem.channelWidthKHz))")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        
                        if !state.comment.isEmpty {
                            Text(state.comment)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .padding(.leading, 2)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
            
        }
        .padding()
        .background(Color.gray.opacity(0.08))
        .cornerRadius(12)
        .sheet(item: $editingItem) { item in
            FrequencyChannelEditorView(
                initialItem: stateStore.effectiveItem(for: satelliteId, item: item),
                initialComment: stateStore.state(for: satelliteId, item: item).comment,
                isNotWorking: stateStore.state(for: satelliteId, item: item).isNotWorking,
                onSave: { rx, tx, spacing, width, comment, isNotWorking in
                    stateStore.setChannelEdits(
                        rxMHz: rx,
                        txMHz: tx,
                        spacingMHz: spacing,
                        channelWidthKHz: width,
                        for: satelliteId,
                        item: item
                    )
                    stateStore.setComment(comment, for: satelliteId, item: item)
                    stateStore.setNotWorking(isNotWorking, for: satelliteId, item: item)
                }
            )
        }
        .sheet(isPresented: $showingAddEditor) {
            FrequencyChannelEditorView(
                initialItem: SatelliteFrequencyItem(rxMHz: nil, txMHz: nil, spacingMHz: nil, channelWidthKHz: nil),
                initialComment: "",
                isNotWorking: false,
                onSave: { rx, tx, spacing, width, comment, isNotWorking in
                    guard rx != nil || tx != nil else { return }
                    let newItem = SatelliteFrequencyItem(
                        rxMHz: rx,
                        txMHz: tx,
                        spacingMHz: spacing,
                        channelWidthKHz: width
                    )
                    libraryStore.addUserChannel(noradId: satelliteId, item: newItem)
                    if !comment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        stateStore.setComment(comment, for: satelliteId, item: newItem)
                    }
                    if isNotWorking {
                        stateStore.setNotWorking(true, for: satelliteId, item: newItem)
                    }
                }
            )
        }
    }
    
    private func format(_ value: Double?) -> String {
        guard let value else { return "—" }
        return String(format: "%.3f MHz", value)
    }
    
    private func formatWidth(_ value: Int?) -> String {
        guard let value else { return "—" }
        return "\(value) кГц"
    }
}

struct FrequencyChannelEditorView: View {
    let initialItem: SatelliteFrequencyItem
    let initialComment: String
    let isNotWorking: Bool
    let onSave: (Double?, Double?, Double?, Int?, String, Bool) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var rxDraft: String
    @State private var txDraft: String
    @State private var spacingDraft: String
    @State private var widthDraft: String
    @State private var comment: String
    @State private var notWorking: Bool
    
    init(
        initialItem: SatelliteFrequencyItem,
        initialComment: String,
        isNotWorking: Bool,
        onSave: @escaping (Double?, Double?, Double?, Int?, String, Bool) -> Void
    ) {
        self.initialItem = initialItem
        self.initialComment = initialComment
        self.isNotWorking = isNotWorking
        self.onSave = onSave
        _rxDraft = State(initialValue: Self.formatDouble(initialItem.rxMHz))
        _txDraft = State(initialValue: Self.formatDouble(initialItem.txMHz))
        _spacingDraft = State(initialValue: Self.formatDouble(initialItem.spacingMHz))
        _widthDraft = State(initialValue: initialItem.channelWidthKHz.map(String.init) ?? "")
        _comment = State(initialValue: initialComment)
        _notWorking = State(initialValue: isNotWorking)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Параметры канала")) {
                    TextField("RX, MHz", text: $rxDraft)
                        .keyboardType(.decimalPad)
                    TextField("TX, MHz", text: $txDraft)
                        .keyboardType(.decimalPad)
                    TextField("Разнос, MHz", text: $spacingDraft)
                        .keyboardType(.decimalPad)
                    TextField("Ширина, кГц", text: $widthDraft)
                        .keyboardType(.numberPad)
                }
                
                Section(header: Text("Комментарий")) {
                    TextEditor(text: $comment)
                        .frame(minHeight: 120)
                }
                
                Section {
                    Toggle("Пометить как \"не работает\"", isOn: $notWorking)
                }
            }
            .navigationTitle("Частота")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Сохранить") {
                        let rx = parseDouble(rxDraft)
                        let tx = parseDouble(txDraft)
                        let spacing = parseDouble(spacingDraft)
                        let width = parseInt(widthDraft)
                        onSave(rx, tx, spacing, width, comment, notWorking)
                        dismiss()
                    }
                }
            }
        }
        .onChange(of: rxDraft) { _ in
            recalculateSpacing()
        }
        .onChange(of: txDraft) { _ in
            recalculateSpacing()
        }
    }
    
    private func recalculateSpacing() {
        guard let rx = parseDouble(rxDraft), let tx = parseDouble(txDraft) else { return }
        spacingDraft = Self.formatDouble(abs(tx - rx))
    }
    
    private func parseDouble(_ value: String) -> Double? {
        let cleaned = value
            .replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return nil }
        return Double(cleaned)
    }
    
    private func parseInt(_ value: String) -> Int? {
        let cleaned = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return nil }
        return Int(cleaned)
    }
    
    private static func formatDouble(_ value: Double?) -> String {
        guard let value else { return "" }
        return String(format: "%.3f", value)
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
