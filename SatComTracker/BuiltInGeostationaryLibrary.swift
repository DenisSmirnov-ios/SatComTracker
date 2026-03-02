import Foundation

struct BuiltInGeostationarySatellite {
    let noradID: Int
    let name: String
    let longitudeDeg: Double
    let altitudeKm: Double
}

enum BuiltInGeostationaryLibrary {
    static let geostationaryAltitudeKm: Double = 35_786.0

    // Generated from satview_extracted/database.csv (rows with non-empty lon).
    static let satellitesByNorad: [Int: BuiltInGeostationarySatellite] = [
        20253: BuiltInGeostationarySatellite(noradID: 20253, name: "125.0°W FltSatCom F8", longitudeDeg: -125.00000, altitudeKm: geostationaryAltitudeKm),
        20776: BuiltInGeostationarySatellite(noradID: 20776, name: "32.0°E Skynet 4C", longitudeDeg: 32.00000, altitudeKm: geostationaryAltitudeKm),
        22787: BuiltInGeostationarySatellite(noradID: 22787, name: "29.2°E UFO F2", longitudeDeg: 29.20000, altitudeKm: geostationaryAltitudeKm),
        23467: BuiltInGeostationarySatellite(noradID: 23467, name: "172.0°E UFO F4", longitudeDeg: 172.00000, altitudeKm: geostationaryAltitudeKm),
        23967: BuiltInGeostationarySatellite(noradID: 23967, name: "22.0°W UFO F7", longitudeDeg: -22.00000, altitudeKm: geostationaryAltitudeKm),
        25639: BuiltInGeostationarySatellite(noradID: 25639, name: "1.0°W Skynet 4E", longitudeDeg: -1.00000, altitudeKm: geostationaryAltitudeKm),
        25967: BuiltInGeostationarySatellite(noradID: 25967, name: "22.0°W UFO F10", longitudeDeg: -22.00000, altitudeKm: geostationaryAltitudeKm),
        28117: BuiltInGeostationarySatellite(noradID: 28117, name: "75.5°E UFO F11", longitudeDeg: 75.50000, altitudeKm: geostationaryAltitudeKm),
        30794: BuiltInGeostationarySatellite(noradID: 30794, name: "95.0°E Skynet 5A", longitudeDeg: 95.00000, altitudeKm: geostationaryAltitudeKm),
        32294: BuiltInGeostationarySatellite(noradID: 32294, name: "25.1°E Skynet 5B", longitudeDeg: 25.10000, altitudeKm: geostationaryAltitudeKm),
        33055: BuiltInGeostationarySatellite(noradID: 33055, name: "17.8°W Skynet 5C", longitudeDeg: -17.80000, altitudeKm: geostationaryAltitudeKm),
        34810: BuiltInGeostationarySatellite(noradID: 34810, name: "11.8°E SICRAL1B", longitudeDeg: 11.80000, altitudeKm: geostationaryAltitudeKm),
        35943: BuiltInGeostationarySatellite(noradID: 35943, name: "63.0°E ComSatBw-1", longitudeDeg: 63.00000, altitudeKm: geostationaryAltitudeKm),
        36582: BuiltInGeostationarySatellite(noradID: 36582, name: "13.2°E ComSatBw-2", longitudeDeg: 13.20000, altitudeKm: geostationaryAltitudeKm),
        38098: BuiltInGeostationarySatellite(noradID: 38098, name: "72.1°E Intelsat 22", longitudeDeg: 72.10000, altitudeKm: geostationaryAltitudeKm),
        39034: BuiltInGeostationarySatellite(noradID: 39034, name: "52.0°E Skynet 5D", longitudeDeg: 52.00000, altitudeKm: geostationaryAltitudeKm),
        40614: BuiltInGeostationarySatellite(noradID: 40614, name: "37.0°E SICRAL 2", longitudeDeg: 37.00000, altitudeKm: geostationaryAltitudeKm),
    ]
}
