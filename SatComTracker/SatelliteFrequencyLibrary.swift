import Foundation

struct SatelliteFrequencyItem: Identifiable, Hashable, Codable {
    let rxMHz: Double?
    let txMHz: Double?
    let spacingMHz: Double?
    let channelWidthKHz: Int?

    var id: String { storageKey }

    var storageKey: String {
        "\(format(rxMHz))|\(format(txMHz))"
    }

    private func format(_ value: Double?) -> String {
        guard let value else { return "nil" }
        return String(format: "%.3f", value)
    }
}

enum SatelliteFrequencyLibrary {
    // Intentionally empty: baseline frequency data is loaded from GitHub and cached locally.
    static let defaultByNorad: [Int: [SatelliteFrequencyItem]] = [:]
}
