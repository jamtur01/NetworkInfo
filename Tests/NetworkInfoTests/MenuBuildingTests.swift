import XCTest
@testable import NetworkInfo

final class MenuBuildingTests: XCTestCase {
    
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
    
    func testBuildMenuWithCompleteData() {
        // Set up test data
        let geoIPData = GeoIPData(query: "71.105.144.84", isp: "UUNET", country: "United States", countryCode: "US")
        let dnsInfo = ["127.0.0.1", "192.168.1.1"]
        let dnsTest = DNSTest(working: true, successRate: 100.0, details: [
            "example.com": DNSTestResult(success: true, response: "93.184.216.34"),
            "google.com": DNSTestResult(success: true, response: "142.250.69.110"),
            "cloudflare.com": DNSTestResult(success: true, response: "104.16.132.229")
        ])
        let vpnConnections = [VPNConnection(interfaceName: "utun4", ip: "10.6.0.2")]
        let dnsConfig = DNSConfig(ssid: "Francis", servers: "127.0.0.1 192.168.1.1", configured: true)
        
        // Populate the manager's data
        manager.setValue("192.168.1.244", forKey: "localIP")
        manager.setValue("Francis", forKey: "ssid")
        manager.setValue(geoIPData, forKey: "geoIPData")
        manager.setValue(dnsInfo, forKey: "dnsInfo")
        manager.setValue(dnsTest, forKey: "dnsTest")
        manager.setValue(vpnConnections, forKey: "vpnConnections")
        manager.setValue(dnsConfig, forKey: "dnsConfiguration")
        
        // Set service states
        var states = manager.value(forKey: "serviceStates") as! [String: ServiceState]
        states["kresd"] = ServiceState(pid: 42028, running: true, responding: true)
        states["unbound"] = ServiceState(pid: 17725, running: true, responding: true)
        manager.setValue(states, forKey: "serviceStates")
        
        // Build the menu
        let menu = NSMenu()
        manager.buildMenu(menu: menu)
        
        // Verify menu structure and content
        XCTAssertGreaterThan(menu.items.count, 5)
        
        // Check specific menu items
        let publicIPItem = menu.items.first { $0.title.contains("Public IP") }
        XCTAssertNotNil(publicIPItem)
        XCTAssertEqual(publicIPItem?.title, "Public IP: 71.105.144.84")
        
        let ssidItem = menu.items.first { $0.title.contains("SSID") }
        XCTAssertNotNil(ssidItem)
        XCTAssertEqual(ssidItem?.title, "SSID: Francis")
        
        let dnsConfigItem = menu.items.first { $0.title.contains("DNS Config") }
        XCTAssertNotNil(dnsConfigItem)
        XCTAssertEqual(dnsConfigItem?.title, "  DNS Config: 127.0.0.1 192.168.1.1")
        
        let ispItem = menu.items.first { $0.title.contains("ISP") }
        XCTAssertNotNil(ispItem)
        XCTAssertEqual(ispItem?.title, "ISP: UUNET")
        
        let locationItem = menu.items.first { $0.title.contains("Location") }
        XCTAssertNotNil(locationItem)
        XCTAssertEqual(locationItem?.title, "Location: United States (US)")
    }
    
    func testBuildMenuWithMinimalData() {
        // Build menu with minimal or no data
        let menu = NSMenu()
        manager.buildMenu(menu: menu)
        
        // The menu should still be created and contain at least basic items
        XCTAssertGreaterThan(menu.items.count, 1)
        
        // Check basic items have fallback values
        let publicIPItem = menu.items.first { $0.title.contains("Public IP") }
        XCTAssertNotNil(publicIPItem)
        XCTAssertTrue(publicIPItem?.title.contains("N/A") ?? false)
        
        let ssidItem = menu.items.first { $0.title.contains("SSID") }
        XCTAssertNotNil(ssidItem)
        XCTAssertTrue(ssidItem?.title.contains("Not connected") ?? false)
    }
    
    func testQuitAndRefreshButtons() {
        // Build menu
        let menu = NSMenu()
        manager.buildMenu(menu: menu)
        
        // Check refresh and quit buttons
        let refreshItem = menu.items.first { $0.title.contains("Refresh") }
        XCTAssertNotNil(refreshItem)
        XCTAssertEqual(refreshItem?.title, "Refresh")
        XCTAssertEqual(refreshItem?.action, #selector(AppDelegate.refreshData(_:)))
        
        let quitItem = menu.items.first { $0.title.contains("Quit") }
        XCTAssertNotNil(quitItem)
        XCTAssertEqual(quitItem?.title, "Quit")
        XCTAssertEqual(quitItem?.action, #selector(AppDelegate.quitApp(_:)))
    }
}