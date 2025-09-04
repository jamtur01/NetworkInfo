import XCTest
@testable import NetworkInfo

final class NetworkInfoTests: XCTestCase {
    
    // MARK: - Setup & Teardown
    
    var manager: NetworkInfoManager!
    
    override func setUp() {
        super.setUp()
        // Setup will be done in each test method that needs MainActor
    }
    
    override func tearDown() {
        manager = nil
        super.tearDown()
    }
    
    // MARK: - DNS Config Tests
    
    @MainActor func testReadDNSConfigWithValidConfig() {
        manager = NetworkInfoManager()
        manager.enableTestMode()
        // Create a temporary config file
        let tempDir = NSTemporaryDirectory()
        let tempConfigPath = tempDir + "test_dns.conf"
        
        // Write test config
        let testConfig = """
        # DNS Configuration file
        # Format: SSID = DNS_Server1 DNS_Server2 ...
        
        HomeWifi = 1.1.1.1 8.8.8.8
        WorkWifi = 192.168.1.1 192.168.1.2
        Francis = 127.0.0.1 192.168.1.1
        EmptySSID = 
        # Comment line
        
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
        
        // Test valid SSID
        let (servers1, found1) = manager.readDNSConfig(ssid: "HomeWifi")
        XCTAssertTrue(found1)
        XCTAssertEqual(servers1, "1.1.1.1 8.8.8.8")
        
        let (servers2, found2) = manager.readDNSConfig(ssid: "Francis")
        XCTAssertTrue(found2)
        XCTAssertEqual(servers2, "127.0.0.1 192.168.1.1")
        
        // Test non-existent SSID
        let (servers3, found3) = manager.readDNSConfig(ssid: "NonExistentSSID")
        XCTAssertFalse(found3)
        XCTAssertNil(servers3)
        
        // Test empty SSID
        let (servers4, found4) = manager.readDNSConfig(ssid: "EmptySSID")
        XCTAssertTrue(found4)
        XCTAssertEqual(servers4, "")
    }
    
    @MainActor func testReadDNSConfigWithInvalidFilePath() {
        manager = NetworkInfoManager()
        manager.enableTestMode()
        let nonExistentPath = "/tmp/non_existent_config_file.conf"
        
        // Temporarily redirect the manager to use the non-existent file
        let originalPath = manager.testDNSConfigPath
        defer {
            manager.setTestDNSConfigPath(originalPath)
        }
        
        manager.setTestDNSConfigPath(nonExistentPath)
        
        // Test should handle non-existent file gracefully
        let (servers, found) = manager.readDNSConfig(ssid: "AnySSID")
        XCTAssertFalse(found)
        XCTAssertNil(servers)
    }
    
    // MARK: - DNS Settings Tests
    
    @MainActor func testUpdateDNSSettings() async {
        manager = NetworkInfoManager()
        manager.enableTestMode()
        // Create a subclass for testing to avoid actual system commands
        class TestableNetworkInfoManager: NetworkInfoManager, @unchecked Sendable {
            @MainActor var commandWasCorrect = false
            
            nonisolated override func updateDNSSettings(dnsServers: String) async -> Bool {
                // Instead of executing real commands, just validate the input
                if dnsServers.isEmpty {
                    Logger.warning("No DNS servers specified", category: "DNS")
                    return false
                }
                
                // Check if the command would have the expected format
                let dnsArray = dnsServers.split(separator: " ").map { String($0) }
                if !dnsArray.isEmpty {
                    let cmd = "/usr/sbin/networksetup -setdnsservers Wi-Fi \(dnsArray.joined(separator: " "))"
                    Logger.info("Would execute: \(cmd)", category: "DNS")
                    Task { @MainActor in
                        commandWasCorrect = true
                    }
                    return true
                }
                
                return false
            }
        }
        
        // Use our testable manager
        let testManager = TestableNetworkInfoManager()
        testManager.enableTestMode()
        
        // Test with valid DNS servers
        let result1 = await testManager.updateDNSSettings(dnsServers: "1.1.1.1 8.8.8.8")
        XCTAssertTrue(result1)
        
        // Wait a moment for the async Task to complete
        let expectation = XCTestExpectation(description: "Command validation")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            Task { @MainActor in
                XCTAssertTrue(testManager.commandWasCorrect)
                expectation.fulfill()
            }
        }
        await fulfillment(of: [expectation], timeout: 1.0)
        
        // Test with empty DNS servers (should return false)
        let result2 = await testManager.updateDNSSettings(dnsServers: "")
        XCTAssertFalse(result2)
    }
    
    // MARK: - Network Data Model Tests
    
    func testDataModelInitialization() {
        // Test GeoIPData
        let geoData = GeoIPData(query: "192.168.1.1", isp: "Test ISP", country: "Test Country", countryCode: "TC")
        XCTAssertEqual(geoData.query, "192.168.1.1")
        XCTAssertEqual(geoData.isp, "Test ISP")
        XCTAssertEqual(geoData.country, "Test Country")
        XCTAssertEqual(geoData.countryCode, "TC")
        
        // Test VPNConnection
        let vpnConnection = VPNConnection(interfaceName: "Test VPN", ip: "10.0.0.1")
        XCTAssertEqual(vpnConnection.name, "Test VPN")
        XCTAssertEqual(vpnConnection.ip, "10.0.0.1")
        
        // Test DNSConfig
        let dnsConfig = DNSConfig(ssid: "Test SSID", servers: "1.1.1.1 8.8.8.8", configured: true)
        XCTAssertEqual(dnsConfig.ssid, "Test SSID")
        XCTAssertEqual(dnsConfig.servers, "1.1.1.1 8.8.8.8")
        XCTAssertTrue(dnsConfig.configured)
    }
    
    // MARK: - Service Status Tests
    
    func testServiceStateDetection() {
        // Test service running detection logic
        let runningState = ServiceState(pid: 1234, running: true, responding: true)
        XCTAssertEqual(runningState.pid?.intValue, 1234)
        XCTAssertTrue(runningState.running)
        XCTAssertTrue(runningState.responding)
        
        // Test service not running
        let stoppedState = ServiceState(pid: nil, running: false, responding: false)
        XCTAssertNil(stoppedState.pid)
        XCTAssertFalse(stoppedState.running)
        XCTAssertFalse(stoppedState.responding)
    }
    
    // MARK: - Helper Tests
    
    func testIPAddressPatternDetection() {
        // Test IP pattern detection used in the code
        let ipAddressPattern = "\\d+\\.\\d+\\.\\d+\\.\\d+"
        
        // Valid IPs should match
        XCTAssertNotNil("192.168.1.1".range(of: ipAddressPattern, options: .regularExpression))
        XCTAssertNotNil("127.0.0.1".range(of: ipAddressPattern, options: .regularExpression))
        XCTAssertNotNil("8.8.8.8".range(of: ipAddressPattern, options: .regularExpression))
        
        // Invalid formats should not match
        XCTAssertNil("not.an.ip.address".range(of: ipAddressPattern, options: .regularExpression))
        XCTAssertNil("".range(of: ipAddressPattern, options: .regularExpression))
        XCTAssertNil("192.168.1".range(of: ipAddressPattern, options: .regularExpression))
    }
}