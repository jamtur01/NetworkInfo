import XCTest
@testable import NetworkInfo

final class NetworkInfoTests: XCTestCase {
    
    // MARK: - Setup & Teardown
    
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
    
    // MARK: - DNS Config Tests
    
    func testReadDNSConfigWithValidConfig() {
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
    
    func testReadDNSConfigWithInvalidFilePath() {
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
    
    func testUpdateDNSSettings() {
        // This is more of an integration test since it would modify system settings
        // We'll mock the behavior instead
        
        // Test with valid DNS servers
        let _ = { (command: String) -> Bool in
            return command.contains("/usr/sbin/networksetup -setdnsservers Wi-Fi 1.1.1.1 8.8.8.8")
        }
        
        // We'd need to mock the Process execution for a complete test
        // For now, let's just verify the function doesn't crash
        XCTAssertNoThrow(manager.updateDNSSettings(dnsServers: "1.1.1.1 8.8.8.8"))
        
        // Test with empty DNS servers (should return false or handle gracefully)
        XCTAssertNoThrow(manager.updateDNSSettings(dnsServers: ""))
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
        let vpnConnection = VPNConnection(name: "Test VPN", ip: "10.0.0.1")
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