import SwiftUI

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
                .animation(
                    isLoading ? Animation.linear(duration: 1).repeatForever(autoreverses: false) : .default,
                    value: isLoading
                )
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
                VisibilityIndicator(
                    visible: visibleCount,
                    hidden: apiService.satellites.count - visibleCount
                )
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
