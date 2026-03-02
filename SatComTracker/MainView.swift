import SwiftUI

struct WelcomeView: View {
    @Binding var showSettings: Bool
    
    var body: some View {
        ZStack {
            AppBackground()
            VStack(spacing: 20) {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 56, weight: .semibold, design: .rounded))
                    .foregroundColor(UITheme.accent)
                
                Text("Требуется настройка")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                
                Text("Добавьте API ключ и выберите спутники")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Button("Перейти в настройки") {
                    showSettings = true
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .appCard(cornerRadius: 20)
            .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct LocationPermissionView: View {
    @ObservedObject var locationManager: LocationManager
    @Binding var showSettings: Bool
    
    var body: some View {
        ZStack {
            AppBackground()
            VStack(spacing: 20) {
                Image(systemName: "location.slash")
                    .font(.system(size: 52, weight: .semibold, design: .rounded))
                    .foregroundColor(.gray)
                
                Text("Нужен доступ к геопозиции")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                
                Text("Для использования GPS необходимо разрешение")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
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
            .appCard(cornerRadius: 20)
            .padding()
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
        .buttonStyle(AppToolbarIconButtonStyle())
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
        ZStack {
            AppBackground()
            VStack(spacing: 10) {
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
}

struct InfoBar: View {
    let lastUpdate: Date
    let refreshInterval: String
    @Environment(\.colorScheme) private var colorScheme
    
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
        .font(.system(size: 12, weight: .semibold, design: .rounded))
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(UITheme.surfaceBackground(for: colorScheme))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(UITheme.cardBorder(for: colorScheme), lineWidth: 1))
        .padding(.horizontal)
    }
}

struct VisibilityIndicator: View {
    let visible: Int
    let hidden: Int
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        HStack(spacing: 16) {
            Label("\(visible)", systemImage: "eye.fill")
                .foregroundColor(.green)
            Label("\(hidden)", systemImage: "eye.slash.fill")
                .foregroundColor(.red)
        }
        .font(.system(size: 12, weight: .semibold, design: .rounded))
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(UITheme.surfaceBackground(for: colorScheme))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(UITheme.cardBorder(for: colorScheme), lineWidth: 1))
        .padding(.horizontal)
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
                    .listRowInsets(EdgeInsets(top: 8, leading: 14, bottom: 6, trailing: 14))
                    .listRowSeparator(.hidden)
            }
            
            ForEach(satellites) { satellite in
                Button(action: { selectedSatellite = satellite }) {
                    SatelliteRow(satellite: satellite)
                }
                .buttonStyle(.plain)
                .listRowInsets(EdgeInsets(top: 6, leading: 14, bottom: 6, trailing: 14))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
        .background(Color.clear)
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
        .appCard(cornerRadius: 14)
        .listRowBackground(Color.clear)
    }
}

struct SatelliteRow: View {
    let satellite: Satellite
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        HStack {
            Image(systemName: satellite.isVisible ? "eye.fill" : "eye.slash.fill")
                .foregroundColor(satellite.isVisible ? .green : .red)
                .font(.caption)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(satellite.name)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
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
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "%.1f°", satellite.elevation))
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(satellite.isVisible ? .green : .red)
                
                if satellite.isError {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(UITheme.surfaceBackground(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(UITheme.cardBorder(for: colorScheme), lineWidth: 1)
        )
        .contentShape(Rectangle())
    }
}
