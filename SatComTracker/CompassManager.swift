import Foundation
import CoreLocation
import Combine

// Менеджер Магнитного Компаса

class CompassManager: NSObject, ObservableObject {
    private let locationManager = CLLocationManager()
    
    @Published var heading: Double = 0.0
    @Published var headingAccuracy: Double = -1.0
    @Published var isAvailable: Bool = false
    @Published var isCalibrating: Bool = false
    
    private var lastContinuousHeading: Double?
    private var smoothedContinuousHeading: Double?
    private let smoothingFactor = 0.20
    
    override init() {
        super.init()
        setupLocationManager()
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.headingFilter = 1.0
        locationManager.activityType = .otherNavigation
    }
    
    func start() {
        guard CLLocationManager.headingAvailable() else {
            isAvailable = false
            return
        }
        
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingHeading()
        isAvailable = true
    }
    
    func stop() {
        locationManager.stopUpdatingHeading()
    }
}

extension CompassManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            start()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        let accuracy = newHeading.headingAccuracy
        
        DispatchQueue.main.async {
            self.headingAccuracy = accuracy
            self.isCalibrating = accuracy < 0 || accuracy > 30
            
            if accuracy >= 0 {
                self.heading = self.smoothedHeading(from: newHeading.magneticHeading)
            }
        }
    }
    
    func locationManagerShouldDisplayHeadingCalibration(_ manager: CLLocationManager) -> Bool {
        return true
    }

    private func smoothedHeading(from rawHeading: Double) -> Double {
        let normalizedRaw = normalize(rawHeading)

        guard let lastContinuousHeading else {
            self.lastContinuousHeading = normalizedRaw
            self.smoothedContinuousHeading = normalizedRaw
            return normalizedRaw
        }

        let previousNormalized = normalize(lastContinuousHeading)
        let delta = shortestDelta(from: previousNormalized, to: normalizedRaw)
        let unwrapped = lastContinuousHeading + delta
        self.lastContinuousHeading = unwrapped

        let previousSmoothed = smoothedContinuousHeading ?? unwrapped
        let smoothed = previousSmoothed + smoothingFactor * (unwrapped - previousSmoothed)
        self.smoothedContinuousHeading = smoothed
        return normalize(smoothed)
    }

    private func shortestDelta(from current: Double, to target: Double) -> Double {
        var delta = target - current
        if delta > 180 { delta -= 360 }
        if delta < -180 { delta += 360 }
        return delta
    }

    private func normalize(_ value: Double) -> Double {
        let wrapped = value.truncatingRemainder(dividingBy: 360)
        return wrapped < 0 ? wrapped + 360 : wrapped
    }
}
