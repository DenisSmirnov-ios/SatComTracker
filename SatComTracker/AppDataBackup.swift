import Foundation

struct AppDataBackupPackage: Codable {
    static let currentSchemaVersion = 1

    var schemaVersion: Int
    var exportedAt: String
    var settings: AppSettings.BackupSnapshot
    var frequencyLibrary: SatelliteFrequencyLibraryStore.BackupSnapshot
    var frequencyStates: [Int: [String: SatelliteFrequencyStateStore.FrequencyState]]
}
