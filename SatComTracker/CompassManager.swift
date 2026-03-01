import Foundation
import CoreLocation
import Combine

// MARK: - 🧭 Менеджер Магнитного Компаса

class CompassManager: NSObject, ObservableObject {
    private let locationManager = CLLocationManager()
    private var headingSubscriber: AnyCancellable?
    
    @Published var heading: Double = 0.0
    @Published var headingAccuracy: Double = -1.0
    @Published var isAvailable: Bool = false
    @Published var isCalibrating: Bool = false
    
    private let headingPublisher = PassthroughSubject<Double, Never>()
    
    override init() {
        super.init()
        setupLocationManager()
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.headingFilter = 1.0
        locationManager.activityType = .otherNavigation
        
        headingSubscriber = headingPublisher
            .debounce(for: .milliseconds(50), scheduler: DispatchQueue.main)
            .sink { [weak self] value in
                self?.heading = value
            }
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
                self.headingPublisher.send(newHeading.magneticHeading)
            }
        }
    }
    
    func locationManagerShouldDisplayHeadingCalibration(_ manager: CLLocationManager) -> Bool {
        return true
    }
}
