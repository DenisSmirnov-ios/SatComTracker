import XCTest
@testable import SatComTracker

final class AppSettingsTests: XCTestCase {
    
    func testNoradIDsParsingAndSerialization() {
        let settings = AppSettings()
        
        settings.noradIDsString = "123, 456,789"
        XCTAssertEqual(settings.noradIDs, [123, 456, 789])
        
        settings.noradIDs = [1, 2, 3]
        XCTAssertEqual(settings.noradIDsString, "1,2,3")
    }
    
    func testCustomIDsParsingAndSerialization() {
        let settings = AppSettings()
        
        settings.customIDsString = "10, 20"
        XCTAssertEqual(settings.customIDs, [10, 20])
        
        settings.addCustomID(30)
        XCTAssertTrue(settings.customIDs.contains(30))
        
        settings.removeCustomID(20)
        XCTAssertFalse(settings.customIDs.contains(20))
    }
    
    func testAllActiveIDsCombinesAndDeduplicates() {
        let settings = AppSettings()
        
        settings.noradIDsString = "1,2,3"
        settings.customIDsString = "3,4"
        
        let all = settings.allActiveIDs.sorted()
        XCTAssertEqual(all, [1,2,3,4])
    }
    
    func testIsConfiguredDependsOnApiKeyAndIDs() {
        let settings = AppSettings()
        
        settings.apiKey = ""
        settings.noradIDsString = ""
        settings.customIDsString = ""
        XCTAssertFalse(settings.isConfigured)
        
        settings.apiKey = "TEST"
        settings.noradIDsString = ""
        settings.customIDsString = ""
        XCTAssertFalse(settings.isConfigured)
        
        settings.noradIDsString = "1"
        XCTAssertTrue(settings.isConfigured)
    }
    
    func testShouldRefreshCacheUsesInterval() {
        let settings = AppSettings()
        
        settings.refreshInterval = 300
        settings.lastCacheUpdate = Date().addingTimeInterval(-600)
        XCTAssertTrue(settings.shouldRefreshCache())
        
        settings.lastCacheUpdate = Date()
        XCTAssertFalse(settings.shouldRefreshCache())
    }
}

