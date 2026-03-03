import SwiftUI

struct ActiveCompassView: View {
    let satelliteAzimuth: Double
    let diameter: CGFloat
    @ObservedObject var compassManager: CompassManager
    @Environment(\.colorScheme) private var colorScheme
    
    var relativeAzimuth: Double {
        let diff = satelliteAzimuth - compassManager.heading
        return (diff.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360)
    }

    private var guidanceGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.10, green: 0.85, blue: 0.92),
                Color(red: 0.11, green: 0.62, blue: 0.98)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    var body: some View {
        let scale = max(0.55, diameter / 332.0)

        ZStack {
            ZStack {
                Circle()
                    .fill(UITheme.surfaceBackground(for: colorScheme).opacity(0.88))
                CompassBackdropView()
                    .clipShape(Circle())
                    .rotationEffect(.degrees(-compassManager.heading))
            }
            .overlay(Circle().stroke(Color.blue.opacity(0.25), lineWidth: 2))
            .frame(width: 332, height: 332)
            
            Text("N")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.red)
                .offset(y: -154)
                .rotationEffect(.degrees(-compassManager.heading))
            
            Text("S")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.blue)
                .offset(y: 154)
                .rotationEffect(.degrees(-compassManager.heading))
            
            Text("W")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .offset(x: -154)
                .rotationEffect(.degrees(-compassManager.heading))
            
            Text("E")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .offset(x: 154)
                .rotationEffect(.degrees(-compassManager.heading))

            Capsule()
                .fill(guidanceGradient)
                .frame(width: 6, height: 152)
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.45), lineWidth: 1)
                )
                .offset(y: -76)
                .rotationEffect(.degrees(relativeAzimuth))
                .shadow(color: Color.cyan.opacity(0.45), radius: 8, x: 0, y: 0)
            
            Triangle()
                .fill(guidanceGradient)
                .frame(width: 26, height: 38)
                .overlay(
                    Triangle()
                        .stroke(Color.white.opacity(0.45), lineWidth: 1)
                )
                .offset(y: -136)
                .rotationEffect(.degrees(relativeAzimuth))
                .shadow(color: Color.cyan.opacity(0.45), radius: 8, x: 0, y: 0)
            
            Circle()
                .fill(Color.white.opacity(0.95))
                .frame(width: 16, height: 16)
                .overlay(
                    Circle()
                        .stroke(guidanceGradient, lineWidth: 4)
                )
                .shadow(color: Color.cyan.opacity(0.4), radius: 6, x: 0, y: 0)
            
            if compassManager.isCalibrating {
                Text("⚠️")
                    .font(.caption)
                    .offset(y: 84)
            }
        }
        .scaleEffect(scale)
        .frame(width: diameter, height: diameter)
        .animation(.linear(duration: 0.16), value: compassManager.heading)
    }
}

private struct CompassBackdropView: View {
    @Environment(\.colorScheme) private var colorScheme

    private var gradientColors: [Color] {
        if colorScheme == .dark {
            return [
                Color(red: 0.07, green: 0.12, blue: 0.20).opacity(0.75),
                Color(red: 0.02, green: 0.06, blue: 0.12).opacity(0.92)
            ]
        }
        return [
            Color(red: 0.82, green: 0.92, blue: 1.00).opacity(0.78),
            Color(red: 0.60, green: 0.78, blue: 0.95).opacity(0.86)
        ]
    }

    private var ringColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.14) : Color.black.opacity(0.20)
    }

    private func tickColor(for angle: Int) -> Color {
        let opacity: Double = angle.isMultiple(of: 45) ? 0.34 : 0.18
        return colorScheme == .dark ? Color.white.opacity(opacity) : Color.black.opacity(opacity + 0.05)
    }

    private var axisColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.25) : Color.black.opacity(0.30)
    }

    var body: some View {
        ZStack {
            RadialGradient(
                colors: gradientColors,
                center: .center,
                startRadius: 8,
                endRadius: 180
            )

            ForEach([55.0, 92.0, 128.0, 152.0], id: \.self) { radius in
                Circle()
                    .stroke(ringColor, lineWidth: 1)
                    .frame(width: radius * 2, height: radius * 2)
            }

            ForEach(Array(stride(from: 0, through: 345, by: 15)), id: \.self) { angle in
                Rectangle()
                    .fill(tickColor(for: angle))
                    .frame(width: angle.isMultiple(of: 45) ? 2 : 1, height: angle.isMultiple(of: 45) ? 22 : 12)
                    .offset(y: -148)
                    .rotationEffect(.degrees(Double(angle)))
            }

            ForEach([0.0, 90.0, 180.0, 270.0], id: \.self) { angle in
                Capsule()
                    .fill(axisColor)
                    .frame(width: 2, height: 42)
                    .offset(y: -122)
                    .rotationEffect(.degrees(angle))
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
    @ObservedObject var settings: AppSettings
    @ObservedObject private var libraryStore = SatelliteFrequencyLibraryStore.shared
    @State private var showingCoverageMap = false
    @State private var showingFrequencyLibrary = false

    private var isPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }
    
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
        GeometryReader { geometry in
            let isLandscape = geometry.size.width > geometry.size.height
            let compactHeight = geometry.size.height < 760
            let horizontalPadding = min(max(geometry.size.width * 0.04, 12), 34)
            let buttonFontSize: CGFloat = compactHeight ? 13 : 14

            Group {
                if isPad && isLandscape {
                    HStack(alignment: .top, spacing: 12) {
                        VStack(spacing: compactHeight ? 10 : 14) {
                            detailControls(
                                compactHeight: compactHeight,
                                buttonFontSize: buttonFontSize,
                                isLandscape: true
                            )

                            if satellite.isVisible {
                                CompassSection(satellite: satellite, compassManager: compassManager)
                                    .frame(maxHeight: .infinity, alignment: .top)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .top)

                        ScrollView {
                            LibraryFrequenciesSection(satelliteId: satellite.id, channels: libraryChannels)
                                .padding(.vertical, 2)
                        }
                        .frame(width: min(max(geometry.size.width * 0.38, 340), 520), alignment: .top)
                    }
                } else if isPad {
                    VStack(spacing: compactHeight ? 10 : 14) {
                        detailControls(
                            compactHeight: compactHeight,
                            buttonFontSize: buttonFontSize,
                            isLandscape: false
                        )

                        if satellite.isVisible {
                            CompassSection(satellite: satellite, compassManager: compassManager)
                                .frame(height: min(max(geometry.size.height * 0.50, 360), 560))
                        }

                        ScrollView {
                            LibraryFrequenciesSection(satelliteId: satellite.id, channels: libraryChannels)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    }
                } else if isLandscape && satellite.isVisible {
                    let controlsWidth = min(max(geometry.size.width * 0.43, 340), 620)
                    HStack(alignment: .top, spacing: 12) {
                        detailControls(
                            compactHeight: compactHeight,
                            buttonFontSize: buttonFontSize,
                            isLandscape: true
                        )
                            .frame(width: controlsWidth, alignment: .top)

                        CompassSection(satellite: satellite, compassManager: compassManager)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    }
                } else {
                    VStack(spacing: compactHeight ? 10 : 14) {
                        detailControls(
                            compactHeight: compactHeight,
                            buttonFontSize: buttonFontSize,
                            isLandscape: false
                        )

                        if satellite.isVisible {
                            CompassSection(satellite: satellite, compassManager: compassManager)
                                .frame(maxHeight: .infinity, alignment: .top)
                        }
                    }
                }
            }
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, compactHeight ? 10 : 14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .background(AppBackground())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            compassManager.start()
        }
        .onDisappear {
            compassManager.stop()
        }
        .fullScreenCover(isPresented: $showingCoverageMap) {
            SatelliteCoverageMapView(satellite: satellite, settings: settings)
        }
        .sheet(isPresented: $showingFrequencyLibrary) {
            FrequencyLibraryWindow(satellite: satellite)
        }
    }

    @ViewBuilder
    private func detailControls(compactHeight: Bool, buttonFontSize: CGFloat, isLandscape: Bool) -> some View {
        VStack(spacing: compactHeight ? 10 : 14) {
            HeaderView(satellite: satellite)
            UpdateTimeView(timestamp: satellite.timestamp, timeFormatter: timeFormatter)

            HStack(spacing: compactHeight ? 8 : 10) {
                Button {
                    showingCoverageMap = true
                } label: {
                    Label("Карта покрытия", systemImage: "map.fill")
                        .font(
                            .system(
                                size: isLandscape ? buttonFontSize + 1 : buttonFontSize,
                                weight: .semibold,
                                design: .rounded
                            )
                        )
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                if !isPad {
                    Button {
                        showingFrequencyLibrary = true
                    } label: {
                        Label("RX/TX", systemImage: "dot.radiowaves.left.and.right")
                            .font(.system(size: buttonFontSize, weight: .semibold, design: .rounded))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .frame(width: isLandscape ? 108 : nil)
                }
            }

            if !satellite.isVisible {
                BelowHorizonWarning(elevation: satellite.elevation)
            }
        }
    }
}

private struct FrequencyLibraryWindow: View {
    let satellite: Satellite
    @ObservedObject private var libraryStore = SatelliteFrequencyLibraryStore.shared
    @Environment(\.dismiss) private var dismiss

    private var channels: [SatelliteFrequencyItem] {
        libraryStore.channels(for: satellite)
    }

    var body: some View {
        NavigationView {
            ScrollView {
                LibraryFrequenciesSection(satelliteId: satellite.id, channels: channels)
                    .padding()
            }
            .background(AppBackground())
            .navigationTitle("RX/TX Частоты")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Готово") { dismiss() }
                }
            }
        }
        .navigationViewStyle(.stack)
    }
}

struct LibraryFrequenciesSection: View {
    let satelliteId: Int
    let channels: [SatelliteFrequencyItem]
    @ObservedObject private var stateStore = SatelliteFrequencyStateStore.shared
    private let libraryStore = SatelliteFrequencyLibraryStore.shared
    @Environment(\.colorScheme) private var colorScheme
    
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
                    .font(.system(size: 19, weight: .semibold, design: .rounded))
                Spacer()
                Button {
                    showingAddEditor = true
                } label: {
                    Label("Добавить", systemImage: "plus.circle")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                }
                .buttonStyle(.borderless)
                
                Text("\(visibleChannels.count)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
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
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundColor(.green)
                            Text("TX \(format(effectiveItem.txMHz))")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundColor(.orange)
                            Spacer()
                            
                            if state.isNotWorking {
                                Text("Offline")
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
                                .font(.system(size: 12, weight: .regular, design: .rounded))
                                .foregroundColor(.secondary)
                                .padding(.leading, 2)
                        }
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(UITheme.surfaceBackground(for: colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(UITheme.cardBorder(for: colorScheme), lineWidth: 1)
                    )
                }
            }
            
        }
        .appCard(cornerRadius: 18)
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
    @Environment(\.colorScheme) private var colorScheme
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
            ScrollView {
                VStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Параметры канала")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))

                        channelField(title: "RX, MHz", text: $rxDraft, keyboard: .decimalPad)
                        channelField(title: "TX, MHz", text: $txDraft, keyboard: .decimalPad)
                        channelField(title: "Разнос, MHz", text: $spacingDraft, keyboard: .decimalPad)
                        channelField(title: "Ширина, кГц", text: $widthDraft, keyboard: .numberPad)
                    }
                    .appCard(cornerRadius: 16)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Комментарий")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))

                        ZStack(alignment: .topLeading) {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(UITheme.surfaceBackground(for: colorScheme))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(UITheme.cardBorder(for: colorScheme), lineWidth: 1)
                                )

                            TextEditor(text: $comment)
                                .font(.system(size: 14, weight: .regular, design: .rounded))
                                .padding(8)
                                .frame(minHeight: 120)
                        }
                    }
                    .appCard(cornerRadius: 16)

                    HStack {
                        Label("Offline", systemImage: notWorking ? "wifi.slash" : "wifi")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                        Spacer()
                        Toggle("", isOn: $notWorking)
                            .labelsHidden()
                    }
                    .appCard(cornerRadius: 16)
                }
                .padding()
            }
            .background(AppBackground())
            .navigationTitle("Канал радиосвязи")
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
        .navigationViewStyle(.stack)
        .onChange(of: rxDraft) { _ in
            recalculateSpacing()
        }
        .onChange(of: txDraft) { _ in
            recalculateSpacing()
        }
    }

    @ViewBuilder
    private func channelField(title: String, text: Binding<String>, keyboard: UIKeyboardType) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            TextField(title, text: text)
                .keyboardType(keyboard)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .padding(.horizontal, 10)
                .padding(.vertical, 10)
                .background(UITheme.surfaceBackground(for: colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(UITheme.cardBorder(for: colorScheme), lineWidth: 1)
                )
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
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: satellite.isVisible ? "circle.fill" : "circle")
                    .font(.system(size: 10))
                    .foregroundColor(satellite.isVisible ? .green : .red)
                
                Text(satellite.name)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            
            Text("NORAD: \(satellite.id)")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(UITheme.surfaceBackground(for: colorScheme))
                .cornerRadius(12)
        }
        .appCard(cornerRadius: 18)
        .padding(.top, 8)
    }
}

struct UpdateTimeView: View {
    let timestamp: Date
    let timeFormatter: DateFormatter
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        HStack {
            Spacer()
            Label(timeFormatter.string(from: timestamp), systemImage: "clock.arrow.circlepath")
                .font(.caption2)
                .foregroundColor(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(UITheme.surfaceBackground(for: colorScheme))
                .cornerRadius(12)
        }
        .padding(.horizontal, 2)
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
        .frame(maxWidth: .infinity)
        .appCard(cornerRadius: 16)
    }
}

struct CompassSection: View {
    let satellite: Satellite
    @ObservedObject var compassManager: CompassManager

    private var remainingTurnDegrees: Double {
        let delta = (satellite.azimuth - compassManager.heading + 540)
            .truncatingRemainder(dividingBy: 360) - 180
        return delta
    }

    private var turnInstructionText: String {
        let delta = remainingTurnDegrees
        if abs(delta) < 2 {
            return "Вы на направлении спутника"
        }
        if delta > 0 {
            return String(format: "Повернитесь вправо еще на %.0f°", abs(delta))
        }
        return String(format: "Повернитесь влево еще на %.0f°", abs(delta))
    }
    
    var body: some View {
        GeometryReader { geometry in
            let height = geometry.size.height
            let width = geometry.size.width
            let ultraCompact = height < 430
            let compact = height < 560 || width < 360
            let verticalReserve: CGFloat = ultraCompact ? 176 : (compact ? 228 : 286)
            let diameterByHeight = max(120, height - verticalReserve)
            let diameterByWidth = max(120, width - (compact ? 24 : 36))
            let compassDiameter = min(diameterByHeight, diameterByWidth, compact ? 280 : 620)
            let metricFont: CGFloat = ultraCompact ? 22 : (compact ? 26 : min(42, compassDiameter * 0.115))
            let stackSpacing: CGFloat = ultraCompact ? 8 : (compact ? 12 : 18)
            let titleFont: Font = ultraCompact ? .subheadline : .headline

            VStack(spacing: stackSpacing) {
                HStack {
                    Label("Наведение на спутник", systemImage: "scope")
                        .font(titleFont)
                    Spacer()
                    if compassManager.isCalibrating {
                        Label("Калибровка", systemImage: "exclamationmark.triangle.fill")
                            .font(ultraCompact ? .caption2 : .caption)
                            .foregroundColor(.orange)
                    }
                }

                ActiveCompassView(
                    satelliteAzimuth: satellite.azimuth,
                    diameter: compassDiameter,
                    compassManager: compassManager
                )
                .frame(maxWidth: .infinity)

                HStack(spacing: ultraCompact ? 14 : (compact ? 22 : 30)) {
                    VStack(spacing: 4) {
                        Text("АЗИМУТ")
                            .font(ultraCompact ? .caption2 : .caption)
                            .foregroundColor(.secondary)
                        Text(String(format: "%.0f°", satellite.azimuth))
                            .font(.system(size: metricFont, weight: .bold, design: .rounded))
                            .foregroundColor(.blue)
                    }

                    Divider()
                        .frame(height: ultraCompact ? 28 : (compact ? 34 : 40))

                    VStack(spacing: 4) {
                        Text("ЭЛЕВАЦИЯ")
                            .font(ultraCompact ? .caption2 : .caption)
                            .foregroundColor(.secondary)
                        Text(String(format: "%.0f°", satellite.elevation))
                            .font(.system(size: metricFont, weight: .bold, design: .rounded))
                            .foregroundColor(.green)
                    }
                }
                .padding(.vertical, ultraCompact ? 0 : (compact ? 2 : 8))

                VStack(alignment: .leading, spacing: ultraCompact ? 6 : (compact ? 8 : 10)) {
                    if ultraCompact {
                        InstructionRow(number: 1, text: turnInstructionText, compact: true)
                        InstructionRow(number: 2, text: String(format: "Элевация %.0f°", satellite.elevation), compact: true)
                    } else {
                        InstructionRow(number: 1, text: "Встаньте лицом на север")
                        InstructionRow(number: 2, text: turnInstructionText)
                        InstructionRow(number: 3, text: String(format: "Поднимите взгляд на %.0f°", satellite.elevation))
                    }
                }
                .padding(ultraCompact ? 10 : (compact ? 12 : 14))
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.blue.opacity(0.05))
                .cornerRadius(12)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .appCard(cornerRadius: 20)
    }
}

struct InstructionRow: View {
    let number: Int
    let text: String
    var compact: Bool = false
    
    var body: some View {
        HStack(spacing: compact ? 8 : 12) {
            Text("\(number)")
                .font(compact ? .caption2 : .caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: compact ? 16 : 20, height: compact ? 16 : 20)
                .background(Circle().fill(Color.blue))
            
            Text(text)
                .font(compact ? .caption : .subheadline)
                .lineLimit(compact ? 1 : 2)
            
            Spacer()
        }
    }
}
