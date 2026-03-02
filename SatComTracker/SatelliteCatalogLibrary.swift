import Foundation

struct CatalogSatellite: Identifiable, Hashable {
    let noradID: Int
    let name: String
    
    var id: Int { noradID }
}

enum SatelliteCatalogLibrary {
    static let satellites: [CatalogSatellite] = [
        CatalogSatellite(noradID: 20253, name: "FLTSATCOM 8 (USA 46)"),
        CatalogSatellite(noradID: 20776, name: "SKYNET 4C"),
        CatalogSatellite(noradID: 22787, name: "UFO 2 (USA 95)"),
        CatalogSatellite(noradID: 23967, name: "UFO 7 (USA 127)"),
        CatalogSatellite(noradID: 25639, name: "SKYNET 4E"),
        CatalogSatellite(noradID: 25967, name: "UFO 10 (USA 146)"),
        CatalogSatellite(noradID: 28117, name: "UFO 11 (USA 174)"),
        CatalogSatellite(noradID: 30794, name: "SKYNET 5A"),
        CatalogSatellite(noradID: 32294, name: "SKYNET 5B"),
        CatalogSatellite(noradID: 33055, name: "SKYNET 5C"),
        CatalogSatellite(noradID: 34810, name: "SICRAL 1B"),
        CatalogSatellite(noradID: 35943, name: "COMSATBW-1"),
        CatalogSatellite(noradID: 36582, name: "COMSATBW-2"),
        CatalogSatellite(noradID: 38098, name: "INTELSAT 20"),
        CatalogSatellite(noradID: 39034, name: "SKYNET 5D"),
        CatalogSatellite(noradID: 40614, name: "SICRAL 2"),
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
