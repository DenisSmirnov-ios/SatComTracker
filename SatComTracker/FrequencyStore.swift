import Foundation
import Combine

// Хранилище частот

class FrequencyStore: ObservableObject {
    static let shared = FrequencyStore()
    
    @Published private(set) var frequencies: [Int: SatelliteFrequencies] = [:]
    @Published private(set) var predefinedFrequencies: [String: [SatelliteFrequencyData]] = [:]
    @Published private(set) var editedFrequencies: [String: [UUID: SatelliteFrequencyData]] = [:]
    
    // Словарь для связи NORAD ID с именем спутника
    private let noradToNameMap: [Int: String] = [
        25967: "UFO 10",
        28117: "UFO 11",
        22787: "UFO 2",
        20253: "FLTSATCOM 8",
        29631: "Skynet 4C",
        30794: "Skynet 4E",
        32283: "Skynet 5A",
        33272: "Skynet 5B",
        36581: "Skynet 5C",
        36582: "Skynet 5D",
        35943: "COMSATBW 1",
        38098: "INTELSAT 22",
        26694: "SICRAL 1",
        34810: "SICRAL 1B",
        40614: "SICRAL 2"
    ]
    
    struct CommunicationChannel: Codable, Identifiable {
        let id: UUID
        var name: String
        var rxFrequency: String
        var txFrequency: String
        var notes: String
        var createdAt: Date
        var isPredefined: Bool
        var originalData: PredefinedOrigin?
        
        struct PredefinedOrigin: Codable {
            let number: Int
            let originalRX: Double
            let originalTX: Double
        }
        
        init(id: UUID = UUID(), name: String = "", rxFrequency: String = "", txFrequency: String = "", notes: String = "", createdAt: Date = Date(), isPredefined: Bool = false, originalData: PredefinedOrigin? = nil) {
            self.id = id
            self.name = name
            self.rxFrequency = rxFrequency
            self.txFrequency = txFrequency
            self.notes = notes
            self.createdAt = createdAt
            self.isPredefined = isPredefined
            self.originalData = originalData
        }
    }
    
    struct SatelliteFrequencies: Codable {
        var channels: [CommunicationChannel]
        
        init(channels: [CommunicationChannel] = []) {
            self.channels = channels
        }
    }
    
    private let storageKey = "satelliteFrequencies"
    private let predefinedKey = "predefinedFrequencies"
    private let editedKey = "editedFrequencies"
    private let saveQueue = DispatchQueue(label: "frequencyStore.saveQueue")
    
    private init() {
        loadEditedFrequencies()
        loadPredefinedFrequencies()
        loadFrequencies()
    }
    
    // Загрузка предустановленных частот
    private func loadPredefinedFrequencies() {
        var frequencies: [String: [SatelliteFrequencyData]] = [:]
        
        let frequencyData: [(Int, Double, Double, Double, Int, String)] = [
            // UFO 11
            (1, 243.625, 316.725, 73.100, 32, "UFO 11"),
            (4, 243.915, 317.015, 73.100, 30, "UFO 11"),
            (5, 243.935, 317.035, 73.100, 6, "UFO 11"),
            (6, 243.945, 317.045, 73.100, 6, "UFO 11"),
            (7, 243.955, 317.055, 73.100, 6, "UFO 11"),
            (8, 243.965, 317.065, 73.100, 6, "UFO 11"),
            (9, 243.975, 317.075, 73.100, 6, "UFO 11"),
            (10, 243.985, 317.085, 73.100, 6, "UFO 11"),
            (14, 244.015, 317.115, 73.100, 6, "UFO 11"),
            (15, 244.030, 317.170, 73.140, 6, "UFO 11"),
            (16, 244.040, 317.230, 73.190, 6, "UFO 11"),
            (17, 244.050, 317.240, 73.190, 6, "UFO 11"),
            (18, 244.060, 317.210, 73.150, 6, "UFO 11"),
            (19, 244.065, 317.165, 73.100, 6, "UFO 11"),
            (21, 244.115, 317.215, 73.100, 6, "UFO 11"),
            (22, 244.155, 317.255, 73.100, 6, "UFO 11"),
            (23, 244.165, 317.265, 73.100, 6, "UFO 11"),
            (24, 244.175, 317.275, 73.100, 6, "UFO 11"),
            (25, 244.185, 317.285, 73.100, 6, "UFO 11"),
            (26, 244.195, 317.295, 73.100, 6, "UFO 11"),
            (27, 244.205, 317.305, 73.100, 6, "UFO 11"),
            (28, 244.225, 316.775, 72.550, 34, "UFO 11"),
            (40, 248.825, 294.375, 45.550, 30, "UFO 11"),
            (41, 248.845, 302.445, 53.600, 6, "UFO 11"),
            (42, 248.855, 302.455, 53.600, 6, "UFO 11"),
            (43, 248.865, 302.465, 53.600, 6, "UFO 11"),
            (44, 248.875, 302.475, 53.600, 6, "UFO 11"),
            (45, 248.885, 302.485, 53.600, 6, "UFO 11"),
            (46, 248.895, 302.495, 53.600, 6, "UFO 11"),
            (47, 248.905, 302.505, 53.600, 6, "UFO 11"),
            (48, 248.915, 302.515, 53.600, 6, "UFO 11"),
            (49, 248.930, 316.975, 68.045, 6, "UFO 11"),
            (50, 248.945, 302.545, 53.600, 6, "UFO 11"),
            (51, 248.955, 302.555, 53.600, 6, "UFO 11"),
            (52, 248.965, 302.565, 53.600, 6, "UFO 11"),
            (55, 248.990, 302.525, 53.535, 6, "UFO 11"),
            (56, 249.000, 302.600, 53.600, 6, "UFO 11"),
            (62, 249.050, 302.650, 53.600, 6, "UFO 11"),
            (68, 249.100, 302.700, 53.600, 6, "UFO 11"),
            (82, 249.235, 302.835, 53.600, 6, "UFO 11"),
            (83, 249.245, 302.845, 53.600, 6, "UFO 11"),
            (85, 249.255, 302.855, 53.600, 6, "UFO 11"),
            (86, 249.265, 302.865, 53.600, 6, "UFO 11"),
            (87, 249.275, 302.875, 53.600, 6, "UFO 11"),
            (88, 249.285, 302.885, 53.600, 6, "UFO 11"),
            (89, 249.295, 302.895, 53.600, 6, "UFO 11"),
            (91, 249.305, 302.905, 53.600, 6, "UFO 11"),
            (92, 249.315, 302.915, 53.600, 6, "UFO 11"),
            (93, 249.325, 302.925, 53.600, 6, "UFO 11"),
            (94, 249.335, 302.935, 53.600, 6, "UFO 11"),
            (95, 249.345, 302.945, 53.600, 6, "UFO 11"),
            (97, 249.355, 302.955, 53.600, 6, "UFO 11"),
            (111, 250.700, 295.050, 44.350, 30, "UFO 11"),
            (117, 251.850, 292.850, 41.000, 34, "UFO 11"),
            (132, 253.550, 294.550, 41.000, 34, "UFO 11"),
            (155, 255.250, 296.250, 41.000, 30, "UFO 11"),
            (166, 256.850, 297.850, 41.000, 30, "UFO 11"),
            (188, 258.350, 299.350, 41.000, 30, "UFO 11"),
            (190, 258.500, 299.500, 41.000, 30, "UFO 11"),
            (192, 258.600, 294.825, 36.225, 8, "UFO 11"),
            (203, 260.375, 293.975, 33.600, 30, "UFO 11"),
            (205, 260.450, 297.575, 37.125, 30, "UFO 11"),
            (206, 260.475, 294.075, 33.600, 30, "UFO 11"),
            (207, 260.500, 317.130, 56.630, 6, "UFO 11"),
            (211, 260.625, 294.225, 33.600, 30, "UFO 11"),
            (220, 261.575, 295.175, 33.600, 30, "UFO 11"),
            (224, 261.675, 295.275, 33.600, 30, "UFO 11"),
            (225, 261.700, 296.525, 34.825, 30, "UFO 11"),
            (231, 261.875, 295.475, 33.600, 30, "UFO 11"),
            (234, 261.950, 294.625, 32.675, 34, "UFO 11"),
            (235, 261.975, 294.000, 32.025, 34, "UFO 11"),
            (247, 263.575, 297.175, 33.600, 30, "UFO 11"),
            (248, 263.600, 317.140, 53.540, 6, "UFO 11"),
            (250, 263.675, 297.275, 33.600, 30, "UFO 11"),
            (252, 263.725, 298.525, 34.800, 30, "UFO 11"),
            (253, 263.750, 317.150, 53.400, 6, "UFO 11"),
            (255, 263.800, 297.250, 33.450, 30, "UFO 11"),
            (256, 263.825, 297.425, 33.600, 30, "UFO 11"),
            (258, 263.925, 297.525, 33.600, 30, "UFO 11"),
            (259, 265.250, 306.250, 41.000, 30, "UFO 11"),
            (260, 265.325, 295.100, 29.775, 30, "UFO 11"),
            (262, 265.375, 295.200, 29.825, 30, "UFO 11"),
            (264, 265.475, 295.500, 30.025, 30, "UFO 11"),
            (268, 266.750, 316.575, 49.825, 30, "UFO 11"),
            (271, 266.975, 297.500, 30.525, 30, "UFO 11"),
            (272, 267.025, 297.350, 30.325, 30, "UFO 11"),
            (278, 267.400, 294.900, 27.500, 30, "UFO 11"),
            (279, 267.575, 297.625, 30.050, 30, "UFO 11"),
            (285, 268.150, 309.150, 41.000, 30, "UFO 11"),
            (286, 268.200, 296.050, 27.850, 30, "UFO 11"),
            (289, 268.450, 297.150, 28.700, 30, "UFO 11"),
            (291, 269.725, 295.150, 25.425, 30, "UFO 11"),
            (294, 269.925, 295.550, 25.625, 30, "UFO 11"),
            
            // UFO 10
            (31, 245.200, 314.450, 69.250, 38, "UFO 10"),
            (69, 249.105, 302.705, 53.600, 6, "UFO 10"),
            (70, 249.115, 302.715, 53.600, 6, "UFO 10"),
            (71, 249.125, 302.725, 53.600, 6, "UFO 10"),
            (72, 249.135, 302.735, 53.600, 6, "UFO 10"),
            (73, 249.145, 302.745, 53.600, 6, "UFO 10"),
            (74, 249.155, 302.755, 53.600, 6, "UFO 10"),
            (75, 249.165, 302.765, 53.600, 6, "UFO 10"),
            (76, 249.175, 302.775, 53.600, 6, "UFO 10"),
            (77, 249.185, 302.785, 53.600, 6, "UFO 10"),
            (78, 249.195, 302.795, 53.600, 6, "UFO 10"),
            (79, 249.205, 302.805, 53.600, 6, "UFO 10"),
            (80, 249.215, 302.815, 53.600, 6, "UFO 10"),
            (81, 249.225, 302.825, 53.600, 6, "UFO 10"),
            (84, 249.250, 302.850, 53.600, 6, "UFO 10"),
            (90, 249.300, 302.900, 53.600, 6, "UFO 10"),
            (96, 249.350, 302.950, 53.600, 6, "UFO 10"),
            (113, 250.950, 299.500, 48.550, 6, "UFO 10"),
            (118, 251.950, 292.950, 41.000, 34, "UFO 10"),
            (119, 252.050, 293.050, 41.000, 34, "UFO 10"),
            (138, 253.750, 294.750, 41.000, 30, "UFO 10"),
            (140, 253.850, 294.850, 41.000, 30, "UFO 10"),
            (170, 257.050, 298.050, 41.000, 30, "UFO 10"),
            (181, 257.500, 311.350, 53.850, 38, "UFO 10"),
            (191, 258.550, 299.550, 41.000, 30, "UFO 10"),
            (204, 260.425, 294.025, 33.600, 30, "UFO 10"),
            (208, 260.525, 294.125, 33.600, 34, "UFO 10"),
            (210, 260.575, 294.175, 33.600, 30, "UFO 10"),
            (213, 260.675, 294.275, 33.600, 34, "UFO 10"),
            (214, 260.725, 295.350, 34.625, 34, "UFO 10"),
            (222, 261.625, 295.225, 33.600, 34, "UFO 10"),
            (226, 261.725, 307.075, 45.350, 34, "UFO 10"),
            (229, 261.825, 295.425, 33.600, 34, "UFO 10"),
            (233, 261.925, 295.525, 33.600, 30, "UFO 10"),
            (238, 262.075, 295.675, 33.600, 30, "UFO 10"),
            (243, 262.375, 295.975, 33.600, 30, "UFO 10"),
            (249, 263.650, 295.075, 31.425, 30, "UFO 10"),
            (251, 263.700, 295.125, 31.425, 30, "UFO 10"),
            (261, 265.350, 306.350, 41.000, 34, "UFO 10"),
            (263, 265.450, 306.450, 41.000, 34, "UFO 10"),
            (269, 266.850, 307.850, 41.000, 30, "UFO 10"),
            (270, 266.950, 307.950, 41.000, 30, "UFO 10"),
            (287, 268.250, 309.250, 41.000, 30, "UFO 10"),
            (288, 268.350, 309.350, 41.000, 30, "UFO 10"),
            (290, 269.650, 310.650, 41.000, 304, "UFO 10"),
            (292, 269.750, 310.750, 41.000, 34, "UFO 10"),
            (293, 269.850, 310.850, 41.000, 30, "UFO 10"),
            
            // UFO 7
            (53, 248.975, 302.575, 53.600, 6, "UFO 7"),
            (54, 248.985, 302.585, 53.600, 6, "UFO 7"),
            (57, 249.005, 302.605, 53.600, 6, "UFO 7"),
            (58, 249.015, 302.615, 53.600, 6, "UFO 7"),
            (59, 249.025, 302.625, 53.600, 6, "UFO 7"),
            (60, 249.035, 302.635, 53.600, 6, "UFO 7"),
            (61, 249.045, 302.645, 53.600, 6, "UFO 7"),
            (63, 249.055, 302.655, 53.600, 6, "UFO 7"),
            (64, 249.065, 302.665, 53.600, 6, "UFO 7"),
            (65, 249.075, 302.675, 53.600, 6, "UFO 7"),
            (66, 249.085, 302.685, 53.600, 6, "UFO 7"),
            (67, 249.095, 302.695, 53.600, 6, "UFO 7"),
            (216, 260.950, 299.400, 38.450, 38, "UFO 7"),
            (240, 262.175, 295.775, 33.600, 30, "UFO 7"),
            (241, 262.275, 300.275, 38.000, 30, "UFO 7"),
            
            // UFO 2
            (157, 255.350, 296.350, 41.000, 34, "UFO 2"),
            (168, 256.950, 297.950, 41.000, 30, "UFO 2"),
            (187, 258.225, 299.300, 41.075, 34, "UFO 2"),
            (189, 258.450, 299.450, 41.000, 34, "UFO 2"),
            (254, 263.775, 297.375, 33.600, 30, "UFO 2"),
            (257, 263.875, 297.475, 33.600, 34, "UFO 2"),
            
            // FLTSATCOM 8 (FLT 8)
            (11, 243.990, 317.090, 73.100, 6, "FLT 8"),
            (12, 243.995, 317.095, 73.100, 6, "FLT 8"),
            (13, 244.000, 317.100, 73.100, 6, "FLT 8"),
            (20, 244.090, 317.190, 73.100, 6, "FLT 8"),
            (120, 252.150, 293.150, 41.000, 34, "FLT 8"),
            (172, 257.140, 298.140, 41.000, 30, "FLT 8"),
            (173, 257.150, 298.150, 41.000, 30, "FLT 8"),
            (175, 257.190, 298.140, 40.950, 30, "FLT 8"),
            (193, 258.650, 299.650, 41.000, 34, "FLT 8"),
            (239, 262.150, 295.750, 33.600, 6, "FLT 8"),
            (242, 262.300, 295.900, 33.600, 6, "FLT 8"),
            (265, 265.550, 306.550, 41.000, 30, "FLT 8"),
            (295, 269.950, 394.325, 24.375, 25, "FLT 8"),
            
            // Comsat BW1
            (98, 249.400, 300.975, 51.575, 34, "Comsat BW1"),
            (162, 255.775, 315.100, 59.325, 34, "Comsat BW1"),
            
            // Comsat BW2
            (2, 243.625, 300.400, 56.775, 30, "Comsat BW2"),
            (39, 248.750, 306.900, 58.150, 38, "Comsat BW2"),
            (112, 250.900, 308.300, 57.400, 38, "Comsat BW2"),
            (195, 259.00, 317.925, 58.925, 34, "Comsat BW2"),
            
            // INTELSAT 22
            (3, 243.800, 298.200, 54.400, 32, "INTELSAT 22"),
            (114, 251.575, 308.450, 56.875, 34, "INTELSAT 22"),
            (115, 251.600, 298.225, 46.625, 30, "INTELSAT 22"),
            (123, 252.300, 293.300, 41.000, 6, "INTELSAT 22"),
            (137, 253.725, 294.050, 40.225, 34, "INTELSAT 22"),
            (143, 253.975, 294.975, 41.000, 6, "INTELSAT 22"),
            (144, 253.990, 298.620, 44.630, 8, "INTELSAT 22"),
            (145, 253.975, 294.975, 41.000, 8, "INTELSAT 22"),
            (146, 254.000, 298.630, 44.630, 8, "INTELSAT 22"),
            (147, 254.025, 295.025, 41.000, 6, "INTELSAT 22"),
            (149, 254.500, 308.100, 53.600, 8, "INTELSAT 22"),
            (150, 254.530, 308.130, 53.600, 8, "INTELSAT 22"),
            (151, 254.625, 295.625, 41.000, 8, "INTELSAT 22"),
            (160, 255.650, 296.650, 41.000, 8, "INTELSAT 22"),
            (161, 255.675, 296.675, 41.000, 8, "INTELSAT 22"),
            (163, 255.850, 296.850, 41.000, 8, "INTELSAT 22"),
            (169, 256.975, 316.850, 59.875, 8, "INTELSAT 22"),
            (185, 257.775, 311.375, 53.600, 30, "INTELSAT 22"),
            (186, 257.825, 297.075, 39.250, 30, "INTELSAT 22"),
            (209, 260.550, 293.800, 33.250, 30, "INTELSAT 22"),
            (221, 261.600, 306.975, 45.375, 30, "INTELSAT 22"),
            (223, 261.650, 309.650, 48.000, 30, "INTELSAT 22"),
            (230, 261.850, 300.275, 38.425, 30, "INTELSAT 22"),
            (266, 265.675, 306.675, 41.000, 30, "INTELSAT 22"),
            (267, 265.850, 306.850, 41.000, 30, "INTELSAT 22"),
            (273, 267.050, 308.050, 41.000, 30, "INTELSAT 22"),
            
            // Skynet 4C
            (29, 244.275, 301.025, 56.750, 34, "Skynet 4C"),
            (30, 244.975, 293.000, 48.025, 30, "Skynet 4C"),
            (35, 246.250, 295.600, 49.350, 6, "Skynet 4C"),
            (36, 246.700, 297.700, 51.000, 30, "Skynet 4C"),
            (38, 248.450, 298.950, 50.500, 30, "Skynet 4C"),
            (104, 249.800, 295.000, 45.200, 34, "Skynet 4C"),
            (184, 257.750, 308.400, 50.650, 30, "Skynet 4C"),
            (194, 258.700, 312.900, 54.200, 30, "Skynet 4C"),
            (219, 261.400, 316.550, 55.150, 30, "Skynet 4C"),
            
            // Skynet 4E
            (148, 254.150, 307.550, 53.400, 36, "Skynet 4E"),
            (183, 257.700, 316.150, 58.450, 34, "Skynet 4E"),
            
            // Skynet 5A
            (33, 245.850, 314.230, 68.380, 38, "Skynet 5A"),
            (182, 257.600, 305.950, 48.350, 34, "Skynet 5A"),
            (217, 261.100, 298.380, 37.280, 30, "Skynet 5A"),
            
            // Skynet 5B
            (100, 249.490, 312.850, 63.360, 34, "Skynet 5B"),
            (102, 249.560, 298.760, 49.200, 8, "Skynet 5B"),
            (103, 249.580, 298.740, 49.160, 8, "Skynet 5B"),
            (106, 249.930, 308.750, 58.820, 6, "Skynet 5B"),
            (108, 250.090, 312.600, 62.510, 34, "Skynet 5B"),
            (130, 252.750, 306.300, 53.550, 30, "Skynet 5B"),
            (131, 253.300, 307.800, 54.500, 30, "Skynet 5B"),
            (218, 261.200, 294.950, 33.750, 38, "Skynet 5B"),
            (244, 263.400, 316.400, 53.000, 6, "Skynet 5B"),
            (245, 263.450, 311.400, 47.950, 6, "Skynet 5B"),
            (246, 263.500, 315.200, 51.700, 6, "Skynet 5B"),
            
            // Skynet 5C
            (32, 245.800, 309.410, 63.610, 38, "Skynet 5C"),
            (99, 249.450, 299.000, 49.550, 30, "Skynet 5C"),
            (101, 249.530, 298.800, 49.270, 34, "Skynet 5C"),
            (109, 250.200, 313.950, 63.750, 30, "Skynet 5C"),
            (139, 253.825, 294.050, 40.225, 34, "Skynet 5C"),
            (141, 253.900, 307.500, 53.600, 30, "Skynet 5C"),
            (167, 256.875, 293.950, 37.075, 30, "Skynet 5C"),
            (180, 257.450, 305.950, 48.500, 38, "Skynet 5C"),
            
            // Skynet 5D
            (34, 245.950, 313.000, 67.050, 38, "Skynet 5D"),
            (37, 247.450, 298.800, 51.350, 30, "Skynet 5D"),
            (105, 249.890, 300.500, 50.610, 34, "Skynet 5D"),
            (142, 253.950, 312.800, 58.850, 38, "Skynet 5D"),
            (152, 254.730, 312.550, 57.820, 34, "Skynet 5D"),
            (164, 256.450, 313.850, 57.400, 6, "Skynet 5D"),
            (215, 260.900, 313.050, 52.150, 38, "Skynet 5D"),
            (236, 262.000, 314.200, 52.200, 34, "Skynet 5D"),
            
            // Sicral 1B
            (124, 252.350, 310.225, 57.875, 30, "Sicral 1B"),
            (125, 252.400, 293.275, 40.875, 34, "Sicral 1B"),
            (126, 252.450, 309.750, 57.300, 34, "Sicral 1B"),
            (127, 252.500, 309.800, 57.300, 34, "Sicral 1B"),
            (128, 252.550, 293.200, 40.650, 34, "Sicral 1B"),
            (129, 252.625, 311.450, 58.825, 34, "Sicral 1B"),
            (198, 260.025, 293.250, 33.225, 30, "Sicral 1B"),
            (199, 260.075, 310.275, 50.200, 34, "Sicral 1B"),
            (200, 260.125, 310.125, 50.000, 34, "Sicral 1B"),
            (201, 260.175, 310.425, 50.250, 34, "Sicral 1B"),
            (202, 260.250, 314.400, 54.150, 30, "Sicral 1B"),
            (280, 267.875, 310.375, 42.500, 30, "Sicral 1B"),
            (281, 267.950, 310.075, 42.125, 30, "Sicral 1B"),
            (282, 268.000, 310.500, 42.500, 30, "Sicral 1B"),
            (284, 268.100, 293.325, 25.225, 30, "Sicral 1B"),
            
            // Sicral 2
            (121, 252.200, 310.175, 57.975, 34, "Sicral 2"),
            (122, 252.250, 316.350, 64.100, 30, "Sicral 2"),
            (176, 257.200, 308.800, 51.600, 34, "Sicral 2"),
            (177, 257.250, 316.900, 59.650, 34, "Sicral 2"),
            (178, 257.300, 309.725, 52.425, 30, "Sicral 2"),
            (179, 257.350, 307.200, 49.850, 34, "Sicral 2"),
            (274, 267.100, 308.100, 41.000, 30, "Sicral 2"),
            (275, 267.150, 308.150, 41.000, 30, "Sicral 2"),
            (276, 267.200, 308.200, 41.000, 30, "Sicral 2"),
            (277, 267.250, 308.250, 41.000, 30, "Sicral 2")
        ]
        
        for data in frequencyData {
            let freq = SatelliteFrequencyData(
                number: data.0,
                rxFrequency: data.1,
                txFrequency: data.2,
                spacing: data.3,
                bandwidth: data.4,
                satelliteName: data.5
            )
            
            let key = data.5
            if frequencies[key] == nil {
                frequencies[key] = []
            }
            frequencies[key]?.append(freq)
        }
        
        // Сортировка частот для каждого спутника
        for (key, value) in frequencies {
            predefinedFrequencies[key] = value.sorted { $0.rxFrequency < $1.rxFrequency }
        }
        
        // Сохраняем в UserDefaults
        if let encoded = try? JSONEncoder().encode(predefinedFrequencies) {
            UserDefaults.standard.set(encoded, forKey: predefinedKey)
        }
    }
    
    // Загрузка и сохранение отредактированных частот
    private func loadEditedFrequencies() {
        guard let data = UserDefaults.standard.data(forKey: editedKey),
              let decoded = try? JSONDecoder().decode([String: [UUID: SatelliteFrequencyData]].self, from: data) else {
            return
        }
        editedFrequencies = decoded
    }
    
    private func saveEditedFrequencies() {
        saveQueue.async { [weak self] in
            guard let self = self,
                  let encoded = try? JSONEncoder().encode(self.editedFrequencies) else { return }
            UserDefaults.standard.set(encoded, forKey: self.editedKey)
        }
    }
    
    // Обновление предустановленной частоты
    func updatePredefinedFrequency(satelliteName: String, frequencyId: UUID, newRX: Double, newTX: Double, newName: String) {
        guard var freqList = predefinedFrequencies[satelliteName],
              let index = freqList.firstIndex(where: { $0.id == frequencyId }) else { return }
        
        var freq = freqList[index]
        freq.rxFrequency = newRX
        freq.txFrequency = newTX
        freq.isEdited = true
        if freq.originalRX == nil {
            freq.originalRX = freqList[index].rxFrequency
            freq.originalTX = freqList[index].txFrequency
        }
        
        freqList[index] = freq
        predefinedFrequencies[satelliteName] = freqList
        
        // Сохраняем в отдельный словарь отредактированных
        if editedFrequencies[satelliteName] == nil {
            editedFrequencies[satelliteName] = [:]
        }
        editedFrequencies[satelliteName]?[frequencyId] = freq
        saveEditedFrequencies()
        
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
    }
    
    // Сброс к оригинальным значениям
    func resetPredefinedFrequency(satelliteName: String, frequencyId: UUID) {
        guard var freqList = predefinedFrequencies[satelliteName],
              let index = freqList.firstIndex(where: { $0.id == frequencyId }),
              let originalRX = freqList[index].originalRX,
              let originalTX = freqList[index].originalTX else { return }
        
        var freq = freqList[index]
        freq.rxFrequency = originalRX
        freq.txFrequency = originalTX
        freq.isEdited = false
        freq.originalRX = nil
        freq.originalTX = nil
        
        freqList[index] = freq
        predefinedFrequencies[satelliteName] = freqList
        
        // Удаляем из отредактированных
        editedFrequencies[satelliteName]?.removeValue(forKey: frequencyId)
        if editedFrequencies[satelliteName]?.isEmpty == true {
            editedFrequencies.removeValue(forKey: satelliteName)
        }
        saveEditedFrequencies()
        
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
    }
    
    // Получение имени спутника по NORAD ID
    func getSatelliteName(for noradID: Int) -> String? {
        return noradToNameMap[noradID]
    }
    
    // Получение предустановленных каналов по NORAD ID
    func getPredefinedChannels(for noradID: Int) -> [CommunicationChannel] {
        // Сначала пытаемся найти по точному соответствию
        if let satelliteName = getSatelliteName(for: noradID),
           let freqList = predefinedFrequencies[satelliteName] {
            return convertToChannels(freqList, satelliteName: satelliteName)
        }
        
        // Если не нашли, пробуем по имени из API (может отличаться)
        return []
    }
    
    private func convertToChannels(_ freqList: [SatelliteFrequencyData], satelliteName: String) -> [CommunicationChannel] {
        return freqList.map { freq in
            let originalData = freq.isEdited ? CommunicationChannel.PredefinedOrigin(
                number: freq.number,
                originalRX: freq.originalRX ?? freq.rxFrequency,
                originalTX: freq.originalTX ?? freq.txFrequency
            ) : nil
            
            return CommunicationChannel(
                id: freq.id,
                name: "Канал \(freq.number)",
                rxFrequency: String(format: "%.3f MHz", freq.rxFrequency),
                txFrequency: String(format: "%.3f MHz", freq.txFrequency),
                notes: "Разнос: \(String(format: "%.3f MHz", freq.spacing)), Полоса: \(freq.bandwidth) кГц",
                isPredefined: true,
                originalData: originalData
            )
        }
    }
    
    func loadFrequencies() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([Int: SatelliteFrequencies].self, from: data) else {
            return
        }
        
        DispatchQueue.main.async {
            self.frequencies = decoded
        }
    }
    
    private func save() {
        saveQueue.async { [weak self] in
            guard let self = self,
                  let encoded = try? JSONEncoder().encode(self.frequencies) else { return }
            
            UserDefaults.standard.set(encoded, forKey: self.storageKey)
            
            DispatchQueue.main.async {
                self.objectWillChange.send()
            }
        }
    }
    
    func getFrequencies(for satId: Int) -> SatelliteFrequencies {
        return frequencies[satId] ?? SatelliteFrequencies()
    }
    
    func addChannel(for satId: Int, channel: CommunicationChannel) {
        var freqs = getFrequencies(for: satId)
        freqs.channels.append(channel)
        frequencies[satId] = freqs
        save()
    }
    
    func updateChannel(for satId: Int, channel: CommunicationChannel) {
        guard var freqs = frequencies[satId],
              let index = freqs.channels.firstIndex(where: { $0.id == channel.id }) else { return }
        
        freqs.channels[index] = channel
        frequencies[satId] = freqs
        save()
    }
    
    func deleteChannel(for satId: Int, channelId: UUID) {
        guard var freqs = frequencies[satId] else { return }
        freqs.channels.removeAll { $0.id == channelId }
        frequencies[satId] = freqs.channels.isEmpty ? nil : freqs
        save()
    }
    
    func clearAll() {
        frequencies.removeAll()
        UserDefaults.standard.removeObject(forKey: storageKey)
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
    }
}
