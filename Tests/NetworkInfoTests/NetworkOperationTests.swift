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
        let expectation = XCTestExpectation(description: "Get local IP address")
        
        // Create a subclass for testing
        class TestableNetworkInfoManager: NetworkInfoManager {
            var localIPCallback: ((String?) -> Void)?
            
            override func getLocalIPAddress() {
                super.getLocalIPAddress()
                
                // Wait a moment for background task to complete
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                    let localIP = self?.value(forKey: "data") as? NetworkData
                    self?.localIPCallback?(localIP?.localIP)
                }
            }
        }
        
        let testManager = TestableNetworkInfoManager()
        testManager.enableTestMode() // Enable test mode for the subclass
        testManager.localIPCallback = { localIP in
            // Local IP should either be a valid IP or N/A
            XCTAssertNotNil(localIP)
            
            // If we got a valid IP, verify format
            if localIP != "N/A" {
                let ipPattern = "^\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}$"
                XCTAssertNotNil(localIP?.range(of: ipPattern, options: .regularExpression))
            }
            
            expectation.fulfill()
        }
        
        testManager.getLocalIPAddress()
        wait(for: [expectation], timeout: 3.0)
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
        let originalPath = manager.value(forKey: "dnsConfigPath") as! String
        defer {
            // Clean up
            try? FileManager.default.removeItem(atPath: tempConfigPath)
            manager.setValue(originalPath, forKey: "dnsConfigPath")
        }
        
        manager.setValue(tempConfigPath, forKey: "dnsConfigPath")
        
        // Force update the data model with test values
        manager.setValue("Francis", forKey: "ssid")
        
        // Create an expectation to wait for the async operation
        let expectation = XCTestExpectation(description: "DNS configuration update")
        
        // Call the method that reads the config
        manager.getCurrentSSID()
        
        // Wait a moment for background tasks to complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            // Verify the DNS config was loaded
            let networkData = self.manager.value(forKey: "data") as! NetworkData
            let dnsConfig = networkData.dnsConfiguration
            XCTAssertNotNil(dnsConfig)
            XCTAssertEqual(dnsConfig?.ssid, "Francis")
            XCTAssertEqual(dnsConfig?.servers, "127.0.0.1 192.168.1.1")
            XCTAssertTrue(dnsConfig?.configured ?? false)
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 3.0)
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
                    let currentData = value(forKey: "data") as! NetworkData
                    currentData.geoIPData = mockData
                    setValue(currentData, forKey: "data")
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
        let testData = testManager.value(forKey: "data") as! NetworkData
        XCTAssertNotNil(testData.geoIPData)
        XCTAssertEqual(testData.geoIPData?.query, "71.105.144.84")
        XCTAssertEqual(testData.geoIPData?.isp, "UUNET")
        XCTAssertEqual(testData.geoIPData?.country, "United States")
        XCTAssertEqual(testData.geoIPData?.countryCode, "US")
        
        expectation.fulfill()
        wait(for: [expectation], timeout: 1.0)
    }
}