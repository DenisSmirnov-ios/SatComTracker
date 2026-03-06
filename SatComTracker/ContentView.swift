import SwiftUI
import UIKit

extension Notification.Name {
    static let settingsChanged = Notification.Name("settingsChanged")
}

struct ContentView: View {
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var locationManager = LocationManager()
    @StateObject private var apiService = SatelliteAPI()
    @StateObject private var settings = AppSettings()
    @StateObject private var compassManager = CompassManager()
    
    @State private var selectedSatellite: Satellite?
    @State private var showSettings = false
    @State private var refreshTask: Task<Void, Never>?
    @State private var shouldRefreshOnAppear = true
    @State private var isUsingFallbackCoordinates = false

    private var isPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
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
                        isUsingFallbackCoordinates: isUsingFallbackCoordinates,
                        selectedSatellite: $selectedSatellite,
                        onRefresh: refreshData,
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
                        isEnabled: settings.updateMode == .automatic,
                        action: refreshData
                    )
                }
            }
        }
        .navigationViewStyle(.stack)
        .preferredColorScheme(settings.preferredColorScheme)
        .sheet(isPresented: $showSettings) {
            SettingsView(settings: settings, locationManager: locationManager)
        }
        .sheet(item: isPad ? .constant(nil) : $selectedSatellite) { satellite in
            satelliteDetailContainer(for: satellite)
        }
        .fullScreenCover(item: isPad ? $selectedSatellite : .constant(nil)) { satellite in
            satelliteDetailContainer(for: satellite)
        }
        .onAppear {
            startServices()
            syncAppIconWithTheme()
            
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
        .onChange(of: settings.themeMode) { _ in
            syncAppIconWithTheme()
        }
        .onChange(of: colorScheme) { _ in
            if settings.themeMode == .system {
                syncAppIconWithTheme()
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
            refreshData()
        }
    }
    
    private func startServices() {
        if settings.locationSource == .gps {
            locationManager.requestLocation()
        }
        compassManager.start()
    }

    private func syncAppIconWithTheme() {
        guard UIApplication.shared.supportsAlternateIcons else { return }

        let desiredIconName: String
        switch settings.themeMode {
        case .light:
            desiredIconName = "AppIconLight"
        case .dark:
            desiredIconName = "AppIconDark"
        case .system:
            desiredIconName = colorScheme == .dark ? "AppIconDark" : "AppIconLight"
        }

        guard UIApplication.shared.alternateIconName != desiredIconName else { return }
        UIApplication.shared.setAlternateIconName(desiredIconName, completionHandler: nil)
    }
    
    private func checkAndRefreshData() {
        Task { @MainActor in
            // Always show the latest cached snapshot immediately on launch.
            apiService.restoreLatestCacheSnapshot()

            if settings.updateMode == .disabled {
                return
            }

            let coords = await getCoordinates()
            guard let coords = coords else { return }

            // Bootstrap on app launch: if no cached snapshot exists yet, fetch once regardless of update mode.
            if settings.lastCacheUpdate == Date.distantPast {
                await apiService.fetchSatellites(
                    apiKey: settings.apiKey,
                    noradIDs: settings.allActiveIDs,
                    latitude: coords.latitude,
                    longitude: coords.longitude,
                    altitude: coords.altitude,
                    refreshInterval: settings.refreshInterval,
                    forceRefresh: true,
                    allowRemoteUpdates: true,
                    onCacheUpdated: { settings.updateCacheTime() }
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
                    allowRemoteUpdates: true,
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
                    allowRemoteUpdates: true,
                    onCacheUpdated: nil
                )
            }
        }
    }
    
    private func refreshData() {
        refreshTask?.cancel()
        refreshTask = Task { @MainActor in
            // Keep UI populated even before location is available or remote fetch is allowed.
            apiService.restoreLatestCacheSnapshot()

            guard settings.updateMode == .automatic else { return }

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
                allowRemoteUpdates: true,
                onCacheUpdated: {
                    settings.updateCacheTime()
                }
            )
        }
    }
    
    private func getCoordinates() async -> (latitude: Double, longitude: Double, altitude: Double)? {
        switch settings.locationSource {
        case .gps:
            if let liveGPS = locationManager.getCurrentCoordinates() {
                isUsingFallbackCoordinates = false
                return liveGPS
            }
            // Simulator (or weak GPS signal) fallback to saved coordinates
            // so satellite data can still be loaded.
            let fallback = settings.getCurrentCoordinates()
            isUsingFallbackCoordinates = fallback != nil
            return fallback
        case .manual, .map:
            isUsingFallbackCoordinates = false
            return settings.getCurrentCoordinates()
        }
    }

    private func deleteSatellite(_ noradID: Int) {
        if selectedSatellite?.id == noradID {
            selectedSatellite = nil
        }
        settings.removeSatellite(noradID)
        refreshData()
    }

    @ViewBuilder
    private func satelliteDetailContainer(for satellite: Satellite) -> some View {
        NavigationView {
            SatelliteDetailView(satellite: satellite, compassManager: compassManager, settings: settings)
        }
        .navigationViewStyle(.stack)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
