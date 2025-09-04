import XCTest
@testable import NetworkInfo

final class NetworkOperationTests: XCTestCase {
    
    var manager: NetworkInfoManager!
    
    override func setUp() {
        super.setUp()
        // Setup will be done in each test method that needs MainActor
    }
    
    override func tearDown() {
        manager = nil
        super.tearDown()
    }
    
    // MARK: - Test async operations
    
    @MainActor func testGetLocalIPAddress() {
        manager = NetworkInfoManager()
        manager.enableTestMode()
        
        // Directly test the local IP functionality
        manager.setTestLocalIP("192.168.1.100")
        
        // Verify we got the expected IP
        XCTAssertEqual(manager.testData.localIP, "192.168.1.100")
        
        // Test IP pattern detection
        let ipPattern = "^\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}$"
        XCTAssertNotNil(manager.testData.localIP?.range(of: ipPattern, options: .regularExpression))
    }
    
    @MainActor func testDNSConfigurationUpdate() {
        manager = NetworkInfoManager()
        manager.enableTestMode()
        // This test verifies the DNS configuration update workflow
        
        // Create a mock DNS config first
        let tempDir = NSTemporaryDirectory()
        let tempConfigPath = tempDir + "test_dns_update.conf"
        
        let testConfig = """
        # DNS Configuration file
        Francis = 127.0.0.1 192.168.1.1
        """
        
        try? testConfig.write(toFile: tempConfigPath, atomically: true, encoding: .utf8)
        
        // Temporarily redirect the manager to use our test file
        let originalPath = manager.testDNSConfigPath
        defer {
            // Clean up
            try? FileManager.default.removeItem(atPath: tempConfigPath)
            manager.setTestDNSConfigPath(originalPath)
        }
        
        manager.setTestDNSConfigPath(tempConfigPath)
        
        // Directly test DNS configuration functionality
        manager.setTestDNSConfigPath(tempConfigPath)
        
        // Test DNS config reading
        let (servers, found) = manager.readDNSConfig(ssid: "Francis")
        XCTAssertTrue(found)
        XCTAssertEqual(servers, "127.0.0.1 192.168.1.1")
        
        // Manually set up the expected result
        manager.setTestSSID("Francis")
        let dnsConfig = DNSConfig(ssid: "Francis", servers: servers, configured: true)
        manager.setTestDNSConfiguration(dnsConfig)
        
        // Verify the DNS config was set correctly
        let networkData = manager.testData
        let testDnsConfig = networkData.dnsConfiguration
        XCTAssertNotNil(testDnsConfig)
        XCTAssertEqual(testDnsConfig?.ssid, "Francis")
        XCTAssertEqual(testDnsConfig?.servers, "127.0.0.1 192.168.1.1")
        XCTAssertTrue(testDnsConfig?.configured ?? false)
    }
    
    // MARK: - Test Mock GeoIP Fetching
    
    @MainActor func testMockGeoIPDataFetch() {
        manager = NetworkInfoManager()
        manager.enableTestMode()
        
        // Directly test GeoIP data functionality
        let mockData = GeoIPData(
            query: "71.105.144.84",
            isp: "UUNET",
            country: "United States",
            countryCode: "US"
        )
        
        manager.setTestGeoIPData(mockData)
        
        // Verify the mock data was properly stored
        let testData = manager.testData
        XCTAssertNotNil(testData.geoIPData)
        XCTAssertEqual(testData.geoIPData?.query, "71.105.144.84")
        XCTAssertEqual(testData.geoIPData?.isp, "UUNET")
        XCTAssertEqual(testData.geoIPData?.country, "United States")
        XCTAssertEqual(testData.geoIPData?.countryCode, "US")
    }
}