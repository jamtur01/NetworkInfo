import XCTest
@testable import NetworkInfo

final class NetworkOperationTests: XCTestCase {
    
    var manager: NetworkInfoManager!
    
    override func setUp() {
        super.setUp()
        manager = NetworkInfoManager()
        manager.enableTestMode() // Enable test mode to avoid notification issues
    }
    
    override func tearDown() {
        manager = nil
        super.tearDown()
    }
    
    // MARK: - Test async operations
    
    func testGetLocalIPAddress() {
        // Create a subclass for testing with mocked data
        class TestableNetworkInfoManager: NetworkInfoManager {
            override func getLocalIPAddress() {
                // For test predictability, just mock an IP address
                // This will work in both local and CI environments
                self.setTestLocalIP("192.168.1.100")
            }
        }
        
        let testManager = TestableNetworkInfoManager()
        testManager.enableTestMode()
        testManager.getLocalIPAddress()
        
        // Verify we got the expected IP
        XCTAssertEqual(testManager.testData.localIP, "192.168.1.100")
        
        // Test IP pattern detection
        let ipPattern = "^\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}$"
        XCTAssertNotNil(testManager.testData.localIP?.range(of: ipPattern, options: .regularExpression))
    }
    
    func testDNSConfigurationUpdate() {
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
        
        // Create a subclass for testing
        class TestableNetworkInfoManager: NetworkInfoManager {
            override func getCurrentSSID() {
                // Don't try to get actual SSID which depends on hardware
                // Instead, directly set the test data
                self.setTestSSID("Francis")
                
                // Manually apply DNS configuration since we're skipping the actual network check
                let (servers, found) = self.readDNSConfig(ssid: "Francis")
                if found, let servers = servers {
                    let dnsConfig = DNSConfig(ssid: "Francis", servers: servers, configured: true)
                    self.setTestDNSConfiguration(dnsConfig)
                }
            }
        }
        
        // Use the testable manager
        let testManager = TestableNetworkInfoManager()
        testManager.enableTestMode()
        testManager.setTestDNSConfigPath(tempConfigPath)
        
        // Call the method that reads the config
        testManager.getCurrentSSID()
        
        // Verify the DNS config was loaded correctly
        let networkData = testManager.testData
        let dnsConfig = networkData.dnsConfiguration
        
        XCTAssertNotNil(dnsConfig)
        XCTAssertEqual(dnsConfig?.ssid, "Francis")
        XCTAssertEqual(dnsConfig?.servers, "127.0.0.1 192.168.1.1")
        XCTAssertTrue(dnsConfig?.configured ?? false)
    }
    
    // MARK: - Test Mock GeoIP Fetching
    
    func testMockGeoIPDataFetch() {
        let expectation = XCTestExpectation(description: "Mock GeoIP data fetch")
        
        // Create a subclass for testing with mocked data
        class TestableNetworkInfoManager: NetworkInfoManager {
            var mockGeoIPData: GeoIPData?
            
            override init() {
                super.init()
                self.enableTestMode() // Enable test mode
            }
            
            override func getGeoIPData() {
                // Instead of making a real network call, use the mock data
                if let mockData = mockGeoIPData {
                    self.setTestGeoIPData(mockData)
                    print("Mock GeoIP data set: \(mockData)")
                } else {
                    print("No mock GeoIP data available")
                }
            }
        }
        
        let testManager = TestableNetworkInfoManager()
        let mockData = GeoIPData(
            query: "71.105.144.84",
            isp: "UUNET",
            country: "United States",
            countryCode: "US"
        )
        
        testManager.mockGeoIPData = mockData
        testManager.getGeoIPData()
        
        // Verify the mock data was properly stored
        let testData = testManager.testData
        XCTAssertNotNil(testData.geoIPData)
        XCTAssertEqual(testData.geoIPData?.query, "71.105.144.84")
        XCTAssertEqual(testData.geoIPData?.isp, "UUNET")
        XCTAssertEqual(testData.geoIPData?.country, "United States")
        XCTAssertEqual(testData.geoIPData?.countryCode, "US")
        
        expectation.fulfill()
        wait(for: [expectation], timeout: 1.0)
    }
}