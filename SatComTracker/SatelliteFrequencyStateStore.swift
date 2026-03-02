import Foundation
import Combine

final class SatelliteFrequencyStateStore: ObservableObject {
    static let shared = SatelliteFrequencyStateStore()
    
    struct FrequencyState: Codable {
        var comment: String = ""
        var isNotWorking: Bool = false
        var isDeleted: Bool = false
        var editedRxMHz: Double?
        var editedTxMHz: Double?
        var editedSpacingMHz: Double?
        var editedChannelWidthKHz: Int?
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
    
    func setChannelEdits(
        rxMHz: Double?,
        txMHz: Double?,
        spacingMHz: Double?,
        channelWidthKHz: Int?,
        for satelliteId: Int,
        item: SatelliteFrequencyItem
    ) {
        update(satelliteId: satelliteId, key: item.storageKey) { state in
            state.editedRxMHz = rxMHz
            state.editedTxMHz = txMHz
            state.editedSpacingMHz = spacingMHz
            state.editedChannelWidthKHz = channelWidthKHz
        }
    }
    
    func effectiveItem(for satelliteId: Int, item: SatelliteFrequencyItem) -> SatelliteFrequencyItem {
        let state = state(for: satelliteId, item: item)
        let rx = state.editedRxMHz ?? item.rxMHz
        let tx = state.editedTxMHz ?? item.txMHz
        let spacing = state.editedSpacingMHz ?? item.spacingMHz
        let width = state.editedChannelWidthKHz ?? item.channelWidthKHz
        return SatelliteFrequencyItem(rxMHz: rx, txMHz: tx, spacingMHz: spacing, channelWidthKHz: width)
    }
    
    func clearAll() {
        statesBySatellite = [:]
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
