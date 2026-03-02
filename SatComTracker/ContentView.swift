import SwiftUI

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

    private enum RefreshTrigger {
        case automatic
        case manual
    }
    
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
                        onRefresh: { refreshData(trigger: .manual) },
                        onDeleteSatellite: deleteSatellite
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
                    .buttonStyle(AppToolbarIconButtonStyle())
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    RefreshButton(
                        isLoading: apiService.isLoading,
                        isEnabled: settings.updateMode != .disabled,
                        action: { refreshData(trigger: .manual) }
                    )
                }
            }
        }
        .preferredColorScheme(settings.preferredColorScheme)
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
                refreshData(trigger: .automatic)
            }
        }
        .onChange(of: locationManager.currentLocation) { _ in
            if settings.locationSource == .gps && settings.shouldRefreshCache() {
                refreshData(trigger: .automatic)
            }
        }
        .onChange(of: settings.manualLatitude) { _ in
            if (settings.locationSource == .manual || settings.locationSource == .map) && settings.shouldRefreshCache() {
                refreshData(trigger: .automatic)
            }
        }
        .onChange(of: settings.manualLongitude) { _ in
            if (settings.locationSource == .manual || settings.locationSource == .map) && settings.shouldRefreshCache() {
                refreshData(trigger: .automatic)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .settingsChanged)) { _ in
            refreshData(trigger: .automatic)
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

            if settings.updateMode != .automatic {
                await apiService.fetchSatellites(
                    apiKey: settings.apiKey,
                    noradIDs: settings.allActiveIDs,
                    latitude: coords.latitude,
                    longitude: coords.longitude,
                    altitude: coords.altitude,
                    refreshInterval: settings.refreshInterval,
                    forceRefresh: true,
                    allowRemoteUpdates: false,
                    onCacheUpdated: nil
                )
                return
            }
            
            if settings.shouldRefreshCache() {
                await apiService.fetchSatellites(
                    apiKey: settings.apiKey,
                    noradIDs: settings.allActiveIDs,
                    latitude: coords.latitude,
                    longitude: coords.longitude,
                    altitude: coords.altitude,
                    refreshInterval: settings.refreshInterval,
                    forceRefresh: true,
                    allowRemoteUpdates: settings.updateMode == .automatic,
                    onCacheUpdated: { settings.updateCacheTime() }
                )
            } else if settings.lastCacheUpdate != Date.distantPast {
                await apiService.fetchSatellites(
                    apiKey: settings.apiKey,
                    noradIDs: settings.allActiveIDs,
                    latitude: coords.latitude,
                    longitude: coords.longitude,
                    altitude: coords.altitude,
                    refreshInterval: settings.refreshInterval,
                    forceRefresh: false,
                    allowRemoteUpdates: settings.updateMode == .automatic,
                    onCacheUpdated: nil
                )
            }
        }
    }
    
    private func refreshData(trigger: RefreshTrigger = .manual) {
        refreshTask?.cancel()
        refreshTask = Task { @MainActor in
            let coords = await getCoordinates()
            guard let coords = coords else { return }

            let allowRemoteUpdates: Bool
            switch settings.updateMode {
            case .automatic:
                allowRemoteUpdates = true
            case .onDemand:
                allowRemoteUpdates = (trigger == .manual)
            case .disabled:
                allowRemoteUpdates = false
            }
            
            await apiService.fetchSatellites(
                apiKey: settings.apiKey,
                noradIDs: settings.allActiveIDs,
                latitude: coords.latitude,
                longitude: coords.longitude,
                altitude: coords.altitude,
                refreshInterval: settings.refreshInterval,
                forceRefresh: true,
                allowRemoteUpdates: allowRemoteUpdates,
                onCacheUpdated: {
                    if allowRemoteUpdates {
                        settings.updateCacheTime()
                    }
                }
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

    private func deleteSatellite(_ noradID: Int) {
        if selectedSatellite?.id == noradID {
            selectedSatellite = nil
        }
        settings.removeSatellite(noradID)
        refreshData(trigger: .automatic)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
