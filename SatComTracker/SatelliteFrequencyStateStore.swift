import Foundation
import Combine

final class SatelliteFrequencyStateStore: ObservableObject {
    static let shared = SatelliteFrequencyStateStore()
    
    struct FrequencyState: Codable {
        var comment: String = ""
        var isNotWorking: Bool = false
        var isDeleted: Bool = false
    }
    
    @Published private(set) var statesBySatellite: [Int: [String: FrequencyState]] = [:]
    
    private let storageKey = "satelliteFrequencyStates"
    private let saveQueue = DispatchQueue(label: "satelliteFrequencyStateStore.saveQueue")
    
    private init() {
        load()
    }
    
    func state(for satelliteId: Int, item: SatelliteFrequencyItem) -> FrequencyState {
        statesBySatellite[satelliteId]?[item.storageKey] ?? FrequencyState()
    }
    
    func setComment(_ comment: String, for satelliteId: Int, item: SatelliteFrequencyItem) {
        update(satelliteId: satelliteId, key: item.storageKey) { state in
            state.comment = comment.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
    
    func setNotWorking(_ isNotWorking: Bool, for satelliteId: Int, item: SatelliteFrequencyItem) {
        update(satelliteId: satelliteId, key: item.storageKey) { state in
            state.isNotWorking = isNotWorking
        }
    }
    
    func setDeleted(_ isDeleted: Bool, for satelliteId: Int, item: SatelliteFrequencyItem) {
        update(satelliteId: satelliteId, key: item.storageKey) { state in
            state.isDeleted = isDeleted
        }
    }
    
    func restoreAllDeleted(for satelliteId: Int) {
        guard var satStates = statesBySatellite[satelliteId] else { return }
        for key in satStates.keys {
            satStates[key]?.isDeleted = false
        }
        statesBySatellite[satelliteId] = satStates
        save()
        objectWillChange.send()
    }
    
    private func update(satelliteId: Int, key: String, mutate: (inout FrequencyState) -> Void) {
        var satStates = statesBySatellite[satelliteId] ?? [:]
        var state = satStates[key] ?? FrequencyState()
        mutate(&state)
        satStates[key] = state
        statesBySatellite[satelliteId] = satStates
        save()
        objectWillChange.send()
    }
    
    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([Int: [String: FrequencyState]].self, from: data) else {
            return
        }
        statesBySatellite = decoded
    }
    
    private func save() {
        let snapshot = statesBySatellite
        saveQueue.async {
            guard let encoded = try? JSONEncoder().encode(snapshot) else { return }
            UserDefaults.standard.set(encoded, forKey: self.storageKey)
        }
    }
}
