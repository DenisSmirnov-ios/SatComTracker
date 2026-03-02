import Foundation

struct CatalogSatellite: Identifiable, Hashable {
    let noradID: Int
    let name: String

    var id: Int { noradID }
}

enum SatelliteCatalogLibrary {
    static let satellites: [CatalogSatellite] = [
        CatalogSatellite(noradID: 20253, name: "125.0°W FltSatCom F8"),
        CatalogSatellite(noradID: 20776, name: "32.0°E Skynet 4C"),
        CatalogSatellite(noradID: 22787, name: "29.2°E UFO F2"),
        CatalogSatellite(noradID: 23467, name: "172.0°E UFO F4"),
        CatalogSatellite(noradID: 23967, name: "22.0°W UFO F7"),
        CatalogSatellite(noradID: 25639, name: "1.0°W Skynet 4E"),
        CatalogSatellite(noradID: 25967, name: "22.0°W UFO F10"),
        CatalogSatellite(noradID: 28117, name: "75.5°E UFO F11"),
        CatalogSatellite(noradID: 30794, name: "95.0°E Skynet 5A"),
        CatalogSatellite(noradID: 32294, name: "25.1°E Skynet 5B"),
        CatalogSatellite(noradID: 33055, name: "17.8°W Skynet 5C"),
        CatalogSatellite(noradID: 34810, name: "11.8°E SICRAL1B"),
        CatalogSatellite(noradID: 35943, name: "63.0°E ComSatBw-1"),
        CatalogSatellite(noradID: 36582, name: "13.2°E ComSatBw-2"),
        CatalogSatellite(noradID: 38098, name: "72.1°E Intelsat 22"),
        CatalogSatellite(noradID: 39034, name: "52.0°E Skynet 5D"),
        CatalogSatellite(noradID: 40614, name: "37.0°E SICRAL 2"),
    ]

    static func search(_ query: String, limit: Int = 20) -> [CatalogSatellite] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let q = normalize(trimmed)
        let exactStarts = satellites.filter { normalize($0.name).hasPrefix(q) }
        let contains = satellites.filter { normalize($0.name).contains(q) || "\($0.noradID)".contains(trimmed) }

        var result: [CatalogSatellite] = []
        var seen = Set<Int>()
        for sat in exactStarts + contains {
            if seen.insert(sat.noradID).inserted {
                result.append(sat)
            }
            if result.count >= limit { break }
        }

        return result
    }

    private static func normalize(_ s: String) -> String {
        s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "  ", with: " ")
    }
}
