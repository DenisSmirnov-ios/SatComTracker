import Foundation
import Combine
import Compression
import PDFKit

final class SatelliteFrequencyLibraryStore: ObservableObject {
    static let shared = SatelliteFrequencyLibraryStore()
    
    enum ImportMode {
        case merge
        case replace
    }
    
    struct ImportSummary {
        let mode: ImportMode
        let parsedRows: Int
        let addedRows: Int
        let duplicateRows: Int
        let satellitesAffected: Int
    }
    
    @Published private(set) var overrideByNorad: [Int: [SatelliteFrequencyItem]]?
    @Published private(set) var mergedByNorad: [Int: [SatelliteFrequencyItem]] = [:]
    
    private struct PersistedState: Codable {
        var overrideByNorad: [Int: [SatelliteFrequencyItem]]?
        var mergedByNorad: [Int: [SatelliteFrequencyItem]]
    }
    
    private let storageKey = "satelliteFrequencyLibraryState"
    
    private init() {
        load()
    }
    
    func channels(for satellite: Satellite) -> [SatelliteFrequencyItem] {
        let base = (overrideByNorad ?? SatelliteFrequencyLibrary.defaultByNorad)[satellite.id] ?? []
        let merged = mergedByNorad[satellite.id] ?? []
        return deduplicated(base + merged)
    }
    
    @discardableResult
    func importFromFile(url: URL, mode: ImportMode) throws -> ImportSummary {
        let imported = try FrequencyImportParser.parse(url: url)
        var addedRows = 0
        var duplicateRows = imported.duplicateRowsInSource
        
        switch mode {
        case .replace:
            overrideByNorad = imported.byNorad
            mergedByNorad = [:]
            addedRows = imported.parsedRows
        case .merge:
            var nextMerged = mergedByNorad
            let baseLibrary = overrideByNorad ?? SatelliteFrequencyLibrary.defaultByNorad
            
            for (noradId, newItems) in imported.byNorad {
                let existing = deduplicated((baseLibrary[noradId] ?? []) + (nextMerged[noradId] ?? []))
                var existingKeys = Set(existing.map(\.storageKey))
                var appended: [SatelliteFrequencyItem] = nextMerged[noradId] ?? []
                
                for item in newItems {
                    if existingKeys.contains(item.storageKey) {
                        duplicateRows += 1
                        continue
                    }
                    existingKeys.insert(item.storageKey)
                    appended.append(item)
                    addedRows += 1
                }
                
                if !appended.isEmpty {
                    nextMerged[noradId] = deduplicated(appended)
                }
            }
            
            mergedByNorad = nextMerged
        }
        
        save()
        
        return ImportSummary(
            mode: mode,
            parsedRows: imported.parsedRows,
            addedRows: addedRows,
            duplicateRows: duplicateRows,
            satellitesAffected: imported.byNorad.count
        )
    }
    
    func addUserChannel(noradId: Int, item: SatelliteFrequencyItem) {
        var nextMerged = mergedByNorad
        let base = (overrideByNorad ?? SatelliteFrequencyLibrary.defaultByNorad)[noradId] ?? []
        let existing = Set((base + (nextMerged[noradId] ?? [])).map(\.storageKey))
        
        guard !existing.contains(item.storageKey) else { return }
        
        nextMerged[noradId, default: []].append(item)
        nextMerged[noradId] = deduplicated(nextMerged[noradId] ?? [])
        mergedByNorad = nextMerged
        save()
    }
    
    func clearAllData() {
        overrideByNorad = [:]
        mergedByNorad = [:]
        save()
    }

    func restoreBuiltInData() {
        overrideByNorad = nil
        mergedByNorad = [:]
        save()
    }
    
    private func deduplicated(_ items: [SatelliteFrequencyItem]) -> [SatelliteFrequencyItem] {
        var seen = Set<String>()
        var result: [SatelliteFrequencyItem] = []
        
        for item in items {
            if seen.insert(item.storageKey).inserted {
                result.append(item)
            }
        }
        return result
    }
    
    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode(PersistedState.self, from: data) else {
            return
        }
        overrideByNorad = decoded.overrideByNorad
        mergedByNorad = decoded.mergedByNorad
    }
    
    private func save() {
        let state = PersistedState(overrideByNorad: overrideByNorad, mergedByNorad: mergedByNorad)
        guard let encoded = try? JSONEncoder().encode(state) else { return }
        UserDefaults.standard.set(encoded, forKey: storageKey)
    }
}

private enum FrequencyImportParser {
    struct ParsedResult {
        let byNorad: [Int: [SatelliteFrequencyItem]]
        let parsedRows: Int
        let duplicateRowsInSource: Int
    }
    
    static func parse(url: URL) throws -> ParsedResult {
        let ext = url.pathExtension.lowercased()
        if ext == "xlsx" {
            return try parseXLSX(url: url)
        }
        if ext == "pdf" {
            return try parsePDF(url: url)
        }
        throw ParseError.unsupportedFileFormat
    }
    
    private static func parseXLSX(url: URL) throws -> ParsedResult {
        let data = try Data(contentsOf: url)
        let zip = try SimpleZipReader(data: data)
        guard let sheetXML = resolvePrimaryWorksheetXML(zip: zip) else {
            throw ParseError.invalidStructure("Worksheet XML not found")
        }
        
        let sharedStrings: [String]
        if let sharedXML = zip.readTextEntry(named: "xl/sharedStrings.xml") {
            sharedStrings = parseSharedStrings(sharedXML)
        } else {
            sharedStrings = []
        }
        
        let rows = parseSheetRows(sheetXML: sheetXML, sharedStrings: sharedStrings)
        guard !rows.isEmpty else {
            throw ParseError.invalidStructure("No rows in worksheet")
        }
        
        let columnMap = detectColumnMap(headerRow: rows[0])
        guard columnMap.rx != nil, columnMap.tx != nil, columnMap.satellite != nil else {
            throw ParseError.invalidStructure("Required columns are missing")
        }
        
        return buildResult(from: Array(rows.dropFirst()), columnMap: columnMap)
    }

    private static func resolvePrimaryWorksheetXML(zip: SimpleZipReader) -> String? {
        if let workbook = zip.readTextEntry(named: "xl/workbook.xml"),
           let rels = zip.readTextEntry(named: "xl/_rels/workbook.xml.rels"),
           let firstSheetRid = regexFirstMatch(
               pattern: "<(?:[A-Za-z0-9_]+:)?sheet[^>]*?r:id=\"([^\"]+)\"[^>]*/?>",
               in: workbook
           ),
           let target = regexFirstMatch(
               pattern: "<Relationship[^>]*?Id=\"\(NSRegularExpression.escapedPattern(for: firstSheetRid))\"[^>]*?Target=\"([^\"]+)\"[^>]*/?>",
               in: rels
           ) {
            let normalizedTarget = target
                .replacingOccurrences(of: "\\", with: "/")
                .replacingOccurrences(of: "../", with: "")
            let fullPath = normalizedTarget.hasPrefix("xl/")
                ? normalizedTarget
                : "xl/\(normalizedTarget)"
            if let xml = zip.readTextEntry(named: fullPath) {
                return xml
            }
        }

        if let xml = zip.readTextEntry(named: "xl/worksheets/sheet1.xml") { return xml }
        if let xml = zip.readTextEntry(named: "xl/worksheets/sheet.xml") { return xml }
        return nil
    }
    
    private static func parsePDF(url: URL) throws -> ParsedResult {
        guard let document = PDFDocument(url: url) else {
            throw ParseError.invalidStructure("PDF cannot be opened")
        }
        
        var rows: [[String: String]] = []
        
        for index in 0..<document.pageCount {
            guard let page = document.page(at: index), let text = page.string else { continue }
            let lines = text.components(separatedBy: .newlines)
            
            for line in lines {
                let raw = line.trimmingCharacters(in: .whitespacesAndNewlines)
                if raw.isEmpty { continue }
                if let parsed = parseFrequencyLine(raw) {
                    rows.append(parsed)
                }
            }
        }
        
        guard !rows.isEmpty else {
            throw ParseError.invalidStructure("No valid frequency rows found in PDF")
        }
        
        let columnMap = ColumnMap(rx: "RX", tx: "TX", spacing: "SPACING", width: "WIDTH", satellite: "SAT")
        return buildResult(from: rows, columnMap: columnMap)
    }
    
    private static func parseFrequencyLine(_ line: String) -> [String: String]? {
        let cleaned = line.replacingOccurrences(of: ",", with: ".")
        let tokens = cleaned.split(whereSeparator: \.isWhitespace).map(String.init)
        guard tokens.count >= 5 else { return nil }
        
        // Expected order: RX TX SPACING WIDTH NORAD
        guard let rx = parseDouble(tokens[0]),
              let tx = parseDouble(tokens[1]),
              let spacing = parseDouble(tokens[2]),
              let width = parseInt(tokens[3]),
              let norad = parseInt(tokens[4]),
              (100.0...500.0).contains(rx),
              (100.0...500.0).contains(tx),
              (0.0...200.0).contains(spacing),
              (1...500).contains(width),
              (10000...99999).contains(norad) else {
            return nil
        }
        
        return [
            "RX": String(format: "%.3f", rx),
            "TX": String(format: "%.3f", tx),
            "SPACING": String(format: "%.3f", spacing),
            "WIDTH": "\(width)",
            "SAT": "\(norad)"
        ]
    }
    
    private struct ColumnMap {
        var rx: String?
        var tx: String?
        var spacing: String?
        var width: String?
        var satellite: String?
    }
    
    private static func detectColumnMap(headerRow: [String: String]) -> ColumnMap {
        var map = ColumnMap()
        
        for (column, value) in headerRow {
            let normalized = normalizeHeader(value)
            if normalized.contains("rx") || normalized.contains("прием") || normalized.contains("приём") {
                map.rx = column
            } else if normalized.contains("tx") || normalized.contains("uplink") || normalized.contains("up") {
                map.tx = column
            } else if normalized.contains("разнос") || normalized.contains("spacing") {
                map.spacing = column
            } else if normalized.contains("ширинаканала") || normalized.contains("ширина") || normalized.contains("bandwidth") {
                map.width = column
            } else if normalized.contains("спутник") || normalized.contains("norad") || normalized.contains("sat") {
                map.satellite = column
            }
        }
        
        return map
    }

    private static func normalizeHeader(_ text: String) -> String {
        text
            .lowercased()
            .folding(options: [.diacriticInsensitive], locale: .current)
            .replacingOccurrences(of: "\u{feff}", with: "")
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "№", with: "")
            .replacingOccurrences(of: ":", with: "")
    }
    
    private static func buildResult(from rows: [[String: String]], columnMap: ColumnMap) -> ParsedResult {
        var byNorad: [Int: [SatelliteFrequencyItem]] = [:]
        var seen = Set<String>()
        var duplicateRows = 0
        var parsedRows = 0
        
        for row in rows {
            guard let satColumn = columnMap.satellite,
                  let satValue = row[satColumn],
                  let norad = parseInt(satValue) else {
                continue
            }
            
            guard let rxColumn = columnMap.rx,
                  let txColumn = columnMap.tx else {
                continue
            }
            
            let rx = parseDouble(row[rxColumn] ?? "")
            let tx = parseDouble(row[txColumn] ?? "")
            if rx == nil && tx == nil { continue }
            
            let spacing = columnMap.spacing.flatMap { parseDouble(row[$0] ?? "") }
            let width = columnMap.width.flatMap { parseInt(row[$0] ?? "") }
            
            let item = SatelliteFrequencyItem(rxMHz: rx, txMHz: tx, spacingMHz: spacing, channelWidthKHz: width)
            let globalKey = "\(norad)#\(item.storageKey)"
            
            if seen.contains(globalKey) {
                duplicateRows += 1
                continue
            }
            seen.insert(globalKey)
            
            byNorad[norad, default: []].append(item)
            parsedRows += 1
        }
        
        for norad in byNorad.keys {
            byNorad[norad] = byNorad[norad]?.sorted {
                ($0.rxMHz ?? .greatestFiniteMagnitude, $0.txMHz ?? .greatestFiniteMagnitude)
                    < ($1.rxMHz ?? .greatestFiniteMagnitude, $1.txMHz ?? .greatestFiniteMagnitude)
            }
        }
        
        return ParsedResult(byNorad: byNorad, parsedRows: parsedRows, duplicateRowsInSource: duplicateRows)
    }
    
    private static func parseDouble(_ raw: String) -> Double? {
        let value = raw
            .replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }
        return Double(value)
    }
    
    private static func parseInt(_ raw: String) -> Int? {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }
        if let intValue = Int(value) { return intValue }
        if let doubleValue = Double(value.replacingOccurrences(of: ",", with: ".")) {
            return Int(doubleValue.rounded())
        }
        return nil
    }
    
    private static func parseSharedStrings(_ xml: String) -> [String] {
        let siBlocks = regexMatchesSimple(
            pattern: "<(?:[A-Za-z0-9_]+:)?si[^>]*>(.*?)</(?:[A-Za-z0-9_]+:)?si>",
            in: xml,
            dotMatchesNewlines: true
        )
        return siBlocks.map { block in
            let textNodes = regexMatchesSimple(
                pattern: "<(?:[A-Za-z0-9_]+:)?t[^>]*>(.*?)</(?:[A-Za-z0-9_]+:)?t>",
                in: block,
                dotMatchesNewlines: true
            )
            let joined = textNodes.joined()
            return decodeXMLEntities(joined)
        }
    }
    
    private static func parseSheetRows(sheetXML: String, sharedStrings: [String]) -> [[String: String]] {
        let rowBlocks = regexMatchesSimple(
            pattern: "<(?:[A-Za-z0-9_]+:)?row[^>]*>(.*?)</(?:[A-Za-z0-9_]+:)?row>",
            in: sheetXML,
            dotMatchesNewlines: true
        )
        var result: [[String: String]] = []
        
        for row in rowBlocks {
            let cellBlocks = regexMatches(
                pattern: "<(?:[A-Za-z0-9_]+:)?c([^>]*)r=\"([A-Z]+)[0-9]+\"([^>]*)>(.*?)</(?:[A-Za-z0-9_]+:)?c>",
                in: row,
                dotMatchesNewlines: true,
                captureGroups: 4
            )
            
            var rowDict: [String: String] = [:]
            for capture in cellBlocks {
                guard capture.count == 4 else { continue }
                let attrs = capture[0] + " " + capture[2]
                let column = capture[1]
                let body = capture[3]
                let type = regexFirstMatch(pattern: "t=\"([^\"]+)\"", in: attrs) ?? ""

                let value: String
                if let valueNode = regexFirstMatch(
                    pattern: "<(?:[A-Za-z0-9_]+:)?v>(.*?)</(?:[A-Za-z0-9_]+:)?v>",
                    in: body,
                    dotMatchesNewlines: true
                ) {
                    if type == "s", let idx = Int(valueNode), idx >= 0, idx < sharedStrings.count {
                        value = sharedStrings[idx]
                    } else {
                        value = decodeXMLEntities(valueNode)
                    }
                } else if type == "inlineStr" || body.contains("<is>") || body.contains(":is>") {
                    let textNodes = regexMatchesSimple(
                        pattern: "<(?:[A-Za-z0-9_]+:)?t[^>]*>(.*?)</(?:[A-Za-z0-9_]+:)?t>",
                        in: body,
                        dotMatchesNewlines: true
                    )
                    let joined = decodeXMLEntities(textNodes.joined())
                    guard !joined.isEmpty else { continue }
                    value = joined
                } else {
                    continue
                }
                
                rowDict[column] = value
            }
            
            if !rowDict.isEmpty {
                result.append(rowDict)
            }
        }
        
        return result
    }
    
    private static func regexFirstMatch(pattern: String, in text: String, dotMatchesNewlines: Bool = false) -> String? {
        regexMatchesSimple(pattern: pattern, in: text, dotMatchesNewlines: dotMatchesNewlines).first
    }
    
    private static func regexMatches(pattern: String, in text: String, dotMatchesNewlines: Bool = false, captureGroups: Int = 1) -> [[String]] {
        let options: NSRegularExpression.Options = dotMatchesNewlines ? [.dotMatchesLineSeparators] : []
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return [] }
        let nsText = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))
        
        return matches.map { match in
            (1...captureGroups).compactMap { idx in
                guard idx < match.numberOfRanges else { return nil }
                let range = match.range(at: idx)
                guard range.location != NSNotFound else { return "" }
                return nsText.substring(with: range)
            }
        }
    }
    
    private static func regexMatchesSimple(pattern: String, in text: String, dotMatchesNewlines: Bool = false) -> [String] {
        regexMatches(pattern: pattern, in: text, dotMatchesNewlines: dotMatchesNewlines, captureGroups: 1)
            .compactMap { $0.first }
    }
    
    private static func decodeXMLEntities(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&#10;", with: "\n")
    }
    
    enum ParseError: LocalizedError {
        case unsupportedFileFormat
        case invalidStructure(String)
        
        var errorDescription: String? {
            switch self {
            case .unsupportedFileFormat:
                return "Поддерживаются только PDF и XLSX файлы."
            case .invalidStructure(let message):
                return "Неверная структура таблицы: \(message)"
            }
        }
    }
}

private struct SimpleZipReader {
    private let data: Data
    private let bytes: [UInt8]
    
    init(data: Data) throws {
        self.data = data
        self.bytes = Array(data)
        _ = try endOfCentralDirectoryOffset()
    }
    
    func readTextEntry(named entryName: String) -> String? {
        guard let entryData = try? readEntry(named: entryName) else { return nil }
        return String(data: entryData, encoding: .utf8)
    }
    
    private func readEntry(named entryName: String) throws -> Data {
        let eocdOffset = try endOfCentralDirectoryOffset()
        let centralDirectoryOffset = Int(le32(at: eocdOffset + 16))
        let totalEntries = Int(le16(at: eocdOffset + 10))
        
        var cursor = centralDirectoryOffset
        for _ in 0..<totalEntries {
            guard le32(at: cursor) == 0x02014B50 else { throw ZipError.invalidArchive }
            
            let method = Int(le16(at: cursor + 10))
            let compressedSize = Int(le32(at: cursor + 20))
            let uncompressedSize = Int(le32(at: cursor + 24))
            let fileNameLength = Int(le16(at: cursor + 28))
            let extraLength = Int(le16(at: cursor + 30))
            let commentLength = Int(le16(at: cursor + 32))
            let localHeaderOffset = Int(le32(at: cursor + 42))
            
            let nameStart = cursor + 46
            let nameEnd = nameStart + fileNameLength
            let name = String(data: data.subdata(in: nameStart..<nameEnd), encoding: .utf8) ?? ""
            
            if name == entryName {
                guard le32(at: localHeaderOffset) == 0x04034B50 else { throw ZipError.invalidArchive }
                let localNameLength = Int(le16(at: localHeaderOffset + 26))
                let localExtraLength = Int(le16(at: localHeaderOffset + 28))
                let payloadStart = localHeaderOffset + 30 + localNameLength + localExtraLength
                let payloadEnd = payloadStart + compressedSize
                let payload = data.subdata(in: payloadStart..<payloadEnd)
                
                switch method {
                case 0:
                    return payload
                case 8:
                    return try inflate(data: payload, expectedSize: uncompressedSize)
                default:
                    throw ZipError.unsupportedCompression
                }
            }
            
            cursor = nameEnd + extraLength + commentLength
        }
        
        throw ZipError.entryNotFound
    }
    
    private func endOfCentralDirectoryOffset() throws -> Int {
        guard bytes.count >= 22 else { throw ZipError.invalidArchive }
        let signature: [UInt8] = [0x50, 0x4B, 0x05, 0x06]
        let minOffset = max(0, bytes.count - 66_000)
        
        for idx in stride(from: bytes.count - 22, through: minOffset, by: -1) {
            if bytes[idx...min(idx + 3, bytes.count - 1)].elementsEqual(signature) {
                return idx
            }
        }
        
        throw ZipError.invalidArchive
    }
    
    private func le16(at offset: Int) -> UInt16 {
        UInt16(bytes[offset]) | (UInt16(bytes[offset + 1]) << 8)
    }
    
    private func le32(at offset: Int) -> UInt32 {
        UInt32(bytes[offset]) |
        (UInt32(bytes[offset + 1]) << 8) |
        (UInt32(bytes[offset + 2]) << 16) |
        (UInt32(bytes[offset + 3]) << 24)
    }
    
    private func inflate(data: Data, expectedSize: Int) throws -> Data {
        let sourceBuffer = Array(data)
        var destination = [UInt8](repeating: 0, count: max(expectedSize, sourceBuffer.count * 3, 1024))
        let destinationCount = destination.count
        
        let decodedSize = destination.withUnsafeMutableBytes { dstBuffer -> Int in
            sourceBuffer.withUnsafeBytes { srcBuffer in
                compression_decode_buffer(
                    dstBuffer.bindMemory(to: UInt8.self).baseAddress!,
                    destinationCount,
                    srcBuffer.bindMemory(to: UInt8.self).baseAddress!,
                    sourceBuffer.count,
                    nil,
                    COMPRESSION_ZLIB
                )
            }
        }
        
        guard decodedSize > 0 else {
            throw ZipError.inflateFailed
        }
        
        return Data(destination.prefix(decodedSize))
    }
    
    enum ZipError: Error {
        case invalidArchive
        case unsupportedCompression
        case entryNotFound
        case inflateFailed
    }
}
